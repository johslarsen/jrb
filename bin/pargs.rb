#!/usr/bin/env ruby
require 'etc'
require 'forwardable'
require 'open3'

module ProgressPrintable
  CLEAR_LINE = "\e[2K\e[1G".freeze

  # Public: Prints a progress of the Includer#each to stderr, which when written
  # to a TTY is overwritten for otherwise silent iterations.
  # Yields the same as Includer#each, and expects it to return:
  #   [header, stdout+"\n", stderr+"\n"]
  #
  # Uses Includer#each and Includer#progress returning [#i, #total].
  #
  # Example:
  #
  #   a = [1,2,3]
  #   class <<a
  #     include ProgressPrintable
  #     def progress
  #       [(@i ||= 1.step).next, size]
  #     end
  #   end
  #   a.each_progress_printed do |n|
  #     [n, "stdout\n"*(n%2), "stderr\n"*(n%2)]
  #   end
  #   # => a
  #   # STDERR: [1/3] 1
  #   # STDERR: stderr
  #   # STDERR: stdout
  #   # STDERR: [2/3] 2 # [overwritten in TTY]
  #   # STDERR: [3/3] 3
  #   # STDERR: stderr
  #   # STDERR: stdout
  def each_progress_printed(stdout: $stdout, stderr: $stderr)
    cl = stderr.tty? ? CLEAR_LINE : ""
    nl = "\n"
    each do |*args, **kvargs|
      restOfProgressLine, out, err =  yield *args, **kvargs
      nl = stderr.tty? && err.empty? && (out.empty? || !stdout.tty?) ? "" : "\n"
      stderr.print "#{cl}[#{progress.join("/")}] #{restOfProgressLine}#{nl}", err
      stderr.flush
      unless out.empty?
        stdout.print out
        stdout.flush
      end
    end
  ensure
    stderr.puts if nl.empty?
  end
end

# Public: Parallel map functor
class PMap
  include Enumerable
  include ProgressPrintable

  DEFAULT_NUM_THREADS = Integer(ENV.fetch("NUM_THREADS", 2*Etc.nprocessors))

  # Public: When PMap#each is called this will:
  # Yield same as enumerator, but in parallel threads. Returned Objects are
  # yielded one-by-one to the PMap#each call in the thread who called it.
  def initialize(enumerator, num_threads: DEFAULT_NUM_THREADS, &worker)
    @num_threads = num_threads
    @enumerator = enumerator.each
    @worker = worker
    @numInput = @numOutput = 0
  end

  # Public: Map in parallel the enumerator with the initialization block, and
  # Yields in callers thread, once per enumerator iteration: the Object returned
  # by a initialization block call, or StandardError if that call threw.
  # Throws non-StandardError Exceptions if initialization block threw that.
  def each
    if block_given?
      @numInput = @numOutput = 0
      input, output = Queue.new, Queue.new
      threads = []
      begin
        @num_threads.times.map do
          threads << Thread.new do
            while (args_kvargs = input.shift) do
              begin
                output << @worker.call(*args_kvargs[0], **args_kvargs[1])
              rescue Exception => e # rescue everything, because we are in a thread
                output << e
              end
            end
          end
        end # start them before adding input,
        @enumerator.each do |*args, **kvargs| # because this might be a lazy enumeration
          @numInput += 1
          input << [args, kvargs]
        end
        input.close # so threads eventually ends gracefully

        until input.empty? && output.empty?
          @numOutput += 1
          yield reraise_non_standard_error(output.shift)
        end # but threads may still have jobs in transit,

        join_all(threads)
        until output.empty? # from final in-transit jobs
          @numOutput += 1
          yield reraise_non_standard_error(output.shift)
        end

        self
      ensure # yield drops here if yieldee breaks, so shut the workers down gracefully
        input.clear # to minimize waiting if we were broken off early
        join_all(threads) # waits while they finish their current job
      end
    else
      enum_for(:each)
    end
  end

  # Returns [Integer #processed, Integer #total]
  def progress
    [@numOutput, @numInput]
  end

  private

  def join_all(threads)
    threads.delete_if do |t|
      t.join
      true
    end
  end

  def reraise_non_standard_error(exception_or_result)
    if Exception === exception_or_result && !(StandardError === exception_or_result)
      raise exception_or_result
    end
    exception_or_result
  end
end

# Public: Parallel map each line from an IO
class PMapLinewise
  # Public: When PMapLinewise#each is called this will:
  # Yields io#each_line in parallel threads. Returned Objects are yielded
  # one-by-one to the PMapLinewise#each call in the thread who called it.
  def initialize(io, num_threads:PMap::DEFAULT_NUM_THREADS, &worker)
    @pfor = PMap.new(linewise_background_reader(io), num_threads: num_threads, &worker)
  end

  private

  extend Forwardable
  attr_reader :pfor
  def_delegators :pfor, :each, :each_progress_printed, :progress

  def linewise_background_reader(io)
    Enumerator.new do |yielded|
      lines = Queue.new
      thread = Thread.new do
        io.each_line do |l|
          lines << l.chomp
        end
        lines.close
      end
      begin
        while (line = lines.shift)
          yielded << line
        end
      ensure
        thread.join
      end
    end
  end
end

# A parallel version of xargs
class PArgs
  # Public: When PArgs#each is called that will once per line in io yield to
  # the calling thread: [stdout, stderr, Process::Status, line, full_cmd] from
  # running cmd appended with (and/or "{}" replaced by) "\0" separated
  # parameters in parallel threads.
  def initialize(cmd = ARGV, io = $stdin, num_threads: PMap::DEFAULT_NUM_THREADS)
    @cmd = cmd
    @pfor = PMapLinewise.new(io, num_threads: num_threads) do |line|
      parameters = line.split("\0")
      cmd = @cmd.map{|arg| arg == "{}" ? parameters.shift : arg} + parameters
      [*Open3.capture3(*cmd), line, cmd]
    end
  end

  private

  extend Forwardable
  attr_reader :pfor
  def_delegators :pfor, :each, :each_progress_printed, :progress
end

if $0 == __FILE__
  Signal.trap("SIGPIPE", "SYSTEM_DEFAULT")
  if ARGV.empty?
    $stderr.puts <<EOF
[NUM_THREADS=#{PMap::DEFAULT_NUM_THREADS}] #{$0} COMMAND [ARGS]...
Run in parallel COMMAND with ARGS and "\\0" separated arguments read linewise
from input that replaces "{}" one-by-one in ARGS and/or appends to them.
EOF
    exit 1
  end
  PArgs.new.each_progress_printed do |exception_or_out, err, status, line|
    if Exception === exception_or_out
      [exception_or_out, "", "\t#{exception_or_out.backtrace.join("\n\t")}\n"]
    else
      exit_msg = status.success? ? nil : " (#{status})"
      ["#{line.dump[1..-2]}#{exit_msg}", exception_or_out, err]
    end
  end
end

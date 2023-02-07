#!/usr/bin/env ruby
require 'optparse'
require 'open3'

# Public: Run a command, but kill it if takes too long.
# Returns [stdout String, Process.Status or nil if timed out]
def timeboxed2(*cmd, timeout: 1.0, term_timeout: 1.0, **opts)
  result = ""
  deadline = Time.now + timeout
  status = Open3.popen2(*cmd, **opts) do |_, out, waiter|
    until out.closed?
      if deadline < Time.now
        kill_gracefully(waiter, timeout: term_timeout)
        break
      end

      begin
        result << out.read_nonblock(4096)
      rescue EOFError # instead of checking out.eof? because that may block!
        break
      rescue IO::WaitReadable
        if (remaining = deadline - Time.now) >= 0
          IO.select([out], [], [], remaining).nil?
        end
      end
    end
    waiter.value
  end
  [result, status]
end

# Public: Kill and join a Process::Waiter thread first with TERM, then try again after timeout seconds with KILL
def kill_gracefully(waiter, timeout: 1.0)
  Process.kill("TERM", waiter.pid)
  return waiter unless waiter.join(timeout).nil?

  Process.kill("KILL", waiter.pid)
  waiter.join
end

if $PROGRAM_NAME == __FILE__
  OptionParser.new do |o|
    o.banner += " <cmd>..."
    o.on("-t", "--timeout SECONDS", Float)
  end.permute!(into: ($opts = {}))
  stdout, result = timeboxed2(*ARGV, timeout: $opts.fetch(:timeout, 1.0))
  print stdout
  exit result&.exitstatus || 110 # ETIMEDOUT
end

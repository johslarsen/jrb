#!/usr/bin/env ruby
require 'optparse'
require 'open3'

# Public: Run a command, but kill it if takes too long.
# Returns [stdout String, Process.Status or nil if timed out]
def timeboxed2(*cmd, timeout: 1.0, **opts)
  result = ""
  deadline = Time.now + timeout
  status = Open3.popen2(*cmd, **opts) do |_, out, thread|
    until out.closed?
      if deadline < Time.now
        thread.kill
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
    thread.value
  end
  [result, status]
end

if $PROGRAM_NAME == __FILE__
  OptionParser.new do |o|
    o.banner += " <cmd>..."
    o.on("-t", "--timeout SECONDS", Float)
  end.permute!(into: ($opts = {}))
  stdout, result = timeboxed2(*ARGV, timeout: $opts.fetch(:timeout, 1.0))
  print stdout
  exit result ? result.exitstatus : 110 # ETIMEDOUT
end

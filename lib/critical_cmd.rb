#!/usr/bin/env ruby

require 'open3'

def critical_cmd(*cmd, **opts)
  output, status = Open3.capture2e(*cmd, **opts)
  unless status.success?
    $stderr.print output
    raise RuntimeError, "`#{cmd.join(" ")}` failed: #{status.inspect}"
  end
  output
end

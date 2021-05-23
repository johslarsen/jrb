#!/usr/bin/env ruby
require 'minitest/autorun'
require 'pssh'
require 'socket'

class PSSHTest < Minitest::Test
  PSSH_BIN = PSSH.new([]).method(:execute).source_location[0]

  def test_cli
    h = Socket.gethostname
    output = `#{PSSH_BIN} #{Socket.gethostname} 127.0.0.1 "echo foo" 2>/dev/null`
    skip "PSSH failed, presumably local SSH access is not configured" if $? != 0
    assert_equal ["127.0.0.1: foo\n", "#{h}: foo\n"], output.lines.sort
  end
end

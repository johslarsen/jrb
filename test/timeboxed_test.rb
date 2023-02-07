#!/usr/bin/env ruby
require 'minitest/autorun'
require 'timeboxed'

class TimeboxedTest < Minitest::Test
  def test_quiet_ok
    assert_equal(["", 0], out_status(*timeboxed2("true")))
  end

  def test_quiet_fail
    assert_equal(["", 1], out_status(*timeboxed2("false")))
  end

  def test_quiet_timedout
    assert_equal(["", nil], out_status(*timeboxed2("sleep", "1", timeout: 1e-3)))
  end

  def test_chatty_ok
    assert_equal(["foo\n", 0], out_status(*timeboxed2("echo", "foo")))
  end

  def test_chatty_fail
    assert_equal(["bar\n", 1], out_status(*timeboxed2("echo bar; false")))
  end

  def test_chatty_cutoff
    assert_equal(["foo\nbar\n", nil], out_status(*timeboxed2("echo foo; sleep 0.001; echo bar; sleep 1; echo baz", timeout: 0.01)))
  end

  def test_resilient_cutoff
    assert_equal(["", nil], out_status(*timeboxed2("trap '' TERM; sleep 0.123456789", timeout: 0.01, term_timeout: 0.01)))

    # The command above is a shell. Signaling it with KILL terminates it immediately and orphans its children
    leftover_children = `ps -eo args`.lines.grep(/0\.123456789/).map { |l| l.split.first }
    assert_equal(["sleep"], leftover_children) # did our best and killed of the shell at least
  end

  private

  def out_status(out, status)
    [out, status&.exitstatus]
  end
end

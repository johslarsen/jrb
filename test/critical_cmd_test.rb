#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative '../lib/critical_cmd'

class CriticalCmdTest < Minitest::Test
  def test_success
    assert_equal "foo\n", critical_cmd("echo", "foo")
  end

  def test_failure
    assert_raises RuntimeError do
      critical_cmd("false")
    end
  end
end

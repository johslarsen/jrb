#!/usr/bin/env ruby
require 'minitest/autorun'
require 'pgroup'
require 'tempfile'

class PGroupTest < Minitest::Test
  PGROUP_BIN = PGroupBy.new(StringIO.new).method(:line2prefixes).source_location[0]

  def test_cli
    Tempfile.open("pgroup_test") do |f|
      f.write <<~EOF
        foo: foo
        foo: bar
        foo: baz
        bar: bar
      EOF
      f.flush

      assert_equal <<~EOF, `#{PGROUP_BIN} #{f.path}`
        foo:
        foo
        baz

        bar, foo:
        bar
      EOF
      assert_equal <<~EOF, `#{PGROUP_BIN} -s -d':' #{f.path}`
        foo:
         baz
         foo

        bar, foo:
         bar
      EOF
    end
  end
end

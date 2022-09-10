#!/usr/bin/env ruby
require 'backport/minitest'
require 'backport/optparse'

class OptionParserTest < Minitest::Test
  def test_into
    option_parser = OptionParser.new do |o|
      o.on("-f", "--foo STR")
      o.on("-b")
    end

    option_parser.permute!(["-f", "foo", "-b"], into: into = {})
    assert_equal({ foo: "foo", b: true }, into)
  end
end

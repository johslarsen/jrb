#!/usr/bin/env ruby
require 'backport/minitest'
require 'backport/optparse'

class OptionParserTest < Minitest::Test
  def test_into
    optionParser = OptionParser.new do |o|
      o.on("-f", "--foo STR")
      o.on("-b")
    end

    optionParser.permute!(["-f", "foo", "-b"], into: into={})
    assert_equal({foo: "foo", b: true}, into)
  end
end

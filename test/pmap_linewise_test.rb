#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative '../bin/pargs'

class PMapLinewiseTest < Minitest::Test
  def test_lines_are_yielded
    input = 1.upto(100).map(&:to_s).to_a
    yielded = PMapLinewise.new(input.join("\n")+"\n") do |line|
      sleep rand/1e5 # to make processing order random
      line
    end.each.to_a
    assert_equal input, yielded.sort_by(&:to_i), "elements processed incorrectly"
    refute_equal input, yielded, "parallelized, so should be out-of-order"
  end
end

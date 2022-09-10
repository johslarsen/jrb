#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative '../bin/pargs'

class PMapTest < Minitest::Test
  def test_mapping_is_parallel
    doubled = PMap.new(1..100) do |n|
      sleep rand / 1e5 # to make processing order random
      n * 2
    end.each.to_a
    assert_equal 2.step(200, 2).to_a, doubled.sort, "elements processed incorrectly"
    refute_equal 2.step(200, 2).to_a, doubled, "parallelized, so should be out-of-order"
  end

  def test_num_threads_is_taken_into_account
    sequentially_processed = PMap.new(1..100, num_threads: 1) do |n|
      sleep rand / 1e5
      n
    end.each.to_a
    assert_equal 1.upto(100).to_a, sequentially_processed
  end

  def test_breaking_output_block_stops_processing
    processed = []
    threads = PMap.new(1..100) do |n|
      sleep rand / 1e5
      processed << n
      n
    end
    threads.each do |n|
      break if n > 50
    end
    assert processed.max.between?(51, 99), "it did not exit early"
  end

  def test_progress_updated_during_prosessing
    pmap = PMap.new(1..100) do
      sleep rand / 1e5
    end
    # assert_equal([0,0], pmap.progress)
    reported_progress = pmap.each.reduce([]) do |arr|
      arr << pmap.progress
    end
    assert_equal [100, 100], pmap.progress

    # NOTE: output is in parallel with processing, so exact progress is indeterministic
    assert(reported_progress.all? { |i, n| i <= n })
    currents, totals = reported_progress.transpose
    assert(currents.all? { |n| n.between?(1, 100) })
    assert_equal currents.sort, currents, "increasing"
    assert(totals.all? { |n| n.between?(1, 100) })
    assert_equal totals.sort, totals, "not decreaseing at least"
    assert_operator currents.uniq.size, :>, 10, "i.e. at least 10 uniq reports are very likely"
  end
end

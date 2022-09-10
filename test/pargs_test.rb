#!/usr/bin/env ruby
require 'minitest/autorun'
require_relative '../bin/pargs'

class PArgsTest < Minitest::Test
  def test_stdin_args_replaces_and_appends
    yielded = Open3.stub(:capture3, %i[out err status]) do
      pargs = PArgs.new(["echo", "{}", "init"], "foo\0bar\na\0b\n")
      pargs.each.to_a
    end
    assert_equal([
                   [:out, :err, :status, "a\0b", %w[echo a init b]],
                   [:out, :err, :status, "foo\0bar", %w[echo foo init bar]]
                 ], yielded.sort)
  end

  PARGS_BIN = PMap.new([]).method(:each).source_location[0]
  def test_cli
    out, err, status = Open3.capture3({ "NUM_THREADS" => "1" }, PARGS_BIN, "echo", stdin_data: "a\nb\n")
    assert status.success?, "#{PARGS_BIN} failed #{status}"
    # NOTE: Order is deterministic because of NUM_THREADS=1
    assert_equal("[1/2] a\n[2/2] b\n", err)
    assert_equal("a\nb\n", out)
  end
end

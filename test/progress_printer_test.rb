#!/usr/bin/env ruby

require 'minitest/autorun'
require '../bin/pargs'

class ProgressPrinterTest < Minitest::Test
  CL = ProgressPrintable::CLEAR_LINE
  def test_foo
    a = [1, 2, 3]
    class << a
      include ProgressPrintable
      def progress
        [(@i ||= 1.step).next, size]
      end
    end
    outerr = StringIO.new
    outerr.stub(:tty?, true) do
      a.each_progress_printed(stdout: outerr, stderr: outerr) do |n|
        [n, "stdout\n" * (n % 2), "stderr\n" * (n % 2)]
      end
      assert_equal(<<~EOF, outerr.string)
        #{CL}[1/3] 1
        stderr
        stdout
        #{CL}[2/3] 2#{CL}[3/3] 3
        stderr
        stdout
      EOF
    end
  end
end

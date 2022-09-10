#!/usr/bin/env ruby
require 'minitest/autorun'
require 'rpath'
require 'tmpdir'

class RPathTest < Minitest::Test
  RPATH_BIN = RPath.method(:relative).source_location[0]

  def test_cli
    Dir.mktmpdir do |to|
      Dir.mktmpdir do |from|
        assert_equal <<~EOF, `#{RPATH_BIN} #{from}/foo #{from}/bar/baz #{to} #{to}/bar #{to}`
          ../#{File.basename from}/foo
          ../#{File.basename from}/bar/baz
          ./
          bar
        EOF
        assert_equal <<~EOF, `#{RPATH_BIN} #{from}/foo #{from}/bar/baz #{to} #{to}/bar #{to}/foo`
          ../../#{File.basename from}/foo
          ../../#{File.basename from}/bar/baz
          ../
          ../bar
        EOF

        %i[foo bar].each { |d| FileUtils.mkdir "#{from}/#{d}" }
        FileUtils.ln_s "#{from}/foo", "#{to}/symlink"
        assert_equal <<~EOF, `#{RPATH_BIN} #{from}/foo #{from}/foo/bar #{from}/bar/baz #{to} #{to}/bar #{to}/symlink`
          ../../#{File.basename from}/foo
          ../../#{File.basename from}/foo/bar
          ../../#{File.basename from}/bar/baz
          ../
          ../bar
        EOF
        assert_equal <<~EOF, `#{RPATH_BIN} -L #{from}/foo #{from}/foo/bar #{from}/bar/baz #{to} #{to}/bar #{to}/symlink`
          ./
          bar
          ../bar/baz
          ../../#{File.basename to}
          ../../#{File.basename to}/bar
        EOF
      end

      assert_empty `#{RPATH_BIN} -L #{to} #{to}/foo/bar / 2>/dev/null`
      refute_equal 0, $?.to_i
      assert_empty `#{RPATH_BIN} -L / #{to} #{to}/foo/bar 2>/dev/null`
      refute_equal 0, $?.to_i
    end
  end
end

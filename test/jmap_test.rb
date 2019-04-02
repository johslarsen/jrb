#!/usr/bin/env ruby
require 'minitest/autorun'
require 'jmap'
require 'tempfile'

class JMapTest < Minitest::Test
  def test_transactions
    Tempfile.open("jmap_test") do |f|
      jMap = JMap.new f.path, nil
      jMap["1+2+...+12"] = 0
      threads = 1.upto(12).each_slice(3).map do |section|
        Thread.new(section) do |ns|
          ns.each do |n|
            jm = n > 8 ? JMap.new(f.path) : jMap
            jm.transaction do |m|
              m["1+2+...+12"] += n
            end
          end
        end
      end
      threads.each{|t| t.join}

      assert_equal 1.upto(12).inject(0, &:+), jMap["1+2+...+12"]
    end
  end

  JMAP_BIN = JMap.new("").method(:transaction).source_location[0]

  def test_cli
    Tempfile.open("jmap_test") do |f|
      begin
        assert_equal %Q{null\n"bar"\n}, `#{JMAP_BIN} -b "" -g foo -s foo='"bar"' -g foo #{f.path}`
        assert_equal [f.path], Dir.glob(f.path+"*")

        assert_equal %Q{"bar"\n123\n}, `#{JMAP_BIN} -g foo -s bar=123 -d foo -g bar #{f.path}`
        assert_equal({"foo"=>"bar"}, JSON.parse(File.read f.path+".bk"))
        assert_equal({"bar"=>123}, JSON.parse(File.read f.path))

        missing = f.path+"_missing"
        refute system(JMAP_BIN, missing, err: :close)
        assert system(JMAP_BIN, "-c", missing)
        assert_empty File.read(missing+".bk")
        assert_equal({}, JSON.parse(File.read missing))
      ensure
        Dir.glob(f.path+"*") {|p| FileUtils.rm p}
      end
    end
  end
end

#!/usr/bin/env ruby
require 'fileutils'
require 'json'

# Public: A JSON backed persistent map.
class JMap
  def initialize(json_file, bk_suffix: ".bk", sorted: false)
    @json_file = json_file
    @bk_suffix = bk_suffix
    @sorted = sorted
  end

  def [](key)
    transaction{|m| m[key]}
  end
  def []=(key, value)
    transaction{|m| m[key] = value}
  end

  def transaction
    File.open(@json_file, "r+") do |f|
      f.flock(File::LOCK_EX)
      FileUtils.cp f.path, f.path+@bk_suffix if @bk_suffix
      json = f.read

      m = JSON.parse(json.empty? ? "{}" : json)
      retval = yield m
      if @sorted
        m, unordered = {}, m
        unordered.keys.sort.each{|k| m[k] = unordered[k]}
      end

      f.rewind
      f.puts(JSON.pretty_generate(m))
      f.truncate(f.pos)

      retval
    end
  end
end

if $0 == __FILE__
  require 'optparse'
  ops = []
  OptionParser.new do |o|
    o.banner += " <map.json>..."
    o.on("-c", "--[no-]create", "Create missing maps")
    o.on("-b", "--backup SUFFIX", "Use file SUFFIX for backups, empty to disable")
    o.on("-o", "--[no-]order", "Whether or not to sort the map (otherwise append updates)")
    o.on("-s", "--set key=JSON", "Set a top-level key to the JSON value") do |kv|
      k,v = kv.split("=", 2)
      raise "Must be <key>=<value>: #{kv.inspect}" unless v
      ops << ->(m){m[k] = JSON.parse v}
    end
    o.on("-d", "--delete key", "Delete a top-level key") do |k|
      ops << ->(m){m.delete k}
    end
    o.on("-g", "--get key", "Output the JSON value of top-level key") do |k|
      ops << ->(m){puts JSON.generate(m[k])}
    end
  end.permute!(into: ($opts={}))
  ARGV.each do |path|
    if $opts[:create] && !File.exist?(path)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)
    end
    bk_suffix = ->(s){s.empty? ? nil : s}.($opts.fetch :backup, ".bk")
    JMap.new(path, bk_suffix: bk_suffix, sorted: $opts[:order]).transaction do |m|
      ops.each{|op| op.call m}
    end
  end
end

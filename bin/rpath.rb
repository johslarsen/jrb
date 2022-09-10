#!/usr/bin/env ruby

module RPath
  # Public: Determine the relative path to target from directory
  def self.relative(target, directory)
    target = File.expand_path(target)
    directory = File.expand_path(directory) << "/"
    target << "/" if directory.start_with?(target)
    return "./" if target == directory

    prefix = shared_root(target, directory)
    "../" * (directory.count("/") - prefix.count("/")) + target[prefix.length..-1]
  end

  def self.shared_root(*paths)
    prefix = shared_prefix(*paths)
    paths.include?(prefix) ? prefix : prefix.gsub(%r{[^/]*$}, "")
  end

  def self.shared_prefix(*strings)
    shortest = strings.min_by(&:length)
    not_shared = shortest.each_char.with_index.find do |c, i|
      !strings.all? { |p| p[i] == c }
    end
    not_shared ? shortest[0...not_shared[1]] : shortest
  end
end

if $PROGRAM_NAME == __FILE__
  require 'optparse'
  OptionParser.new do |o|
    o.banner += " <target>... <directory>"
    o.on("-L", "--[no-]dereference", "Follow symlinks (dirname of all arguments must exist)")
  end.permute!(into: ($opts = {}))

  directory = ARGV[-1]
  directory = File.realdirpath(directory) if $opts[:dereference]
  relative = ARGV[0..-2].map do |target|
    target = File.realdirpath(target) if $opts[:dereference]
    RPath.relative(target, directory)
  end.to_a

  # common use is `ln -s $(rpath.rb FOO... DIR) DIR`. resolve all paths before
  # printing, so any errors result in "", which harmlessly crashes e.g. `ln`
  puts relative
end

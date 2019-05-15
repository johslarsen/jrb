#!/usr/bin/env ruby

# Public: Group lines of a file by a prefix (e.g. "file: rest").
class PGroupBy

  DEFAULT_DELIMITER = / *: */

  attr_reader :line2prefixes, :prefixes2lines

  def initialize(file, delimiter: nil)
    @line2prefixes = Hash.new{|h,k| h[k] = {}}
    file.each_line do |l|
      prefix, rest = l.chomp.split(delimiter||DEFAULT_DELIMITER, 2)
      rest ? @line2prefixes[rest.to_sym][prefix.to_sym] = true : line2prefixes[prefix.to_sym]
    end
    @prefixes2lines = Hash.new{|h,k| h[k] = []}
    @line2prefixes.each do |l,prefixes|
      @line2prefixes[l] = prefixes.keys.sort
      @prefixes2lines[@line2prefixes[l]] << l
    end
  end
end

if $0 == __FILE__
  Signal.trap("SIGPIPE", "SYSTEM_DEFAULT")

  require 'optparse'
  OptionParser.new do |o|
    o.banner << " [FILE...]"
    o.on("-d", "--delimiter REGEXP", "Use this to separate prefix and rest", Regexp)
    o.on("-s", "--[no-]intra-group-sort", "Output the lines within groups in lexical order")
  end.permute!(ARGV, into: $opts={})
  pGroupBy = PGroupBy.new(ARGF, delimiter: $opts[:delimiter])
  groups = pGroupBy.prefixes2lines.sort_by{|p,_| [p.size]}.map do |prefix,lines|
    lines = $opts[:"intra-group-sort"] ? lines.sort : lines
    "#{prefix.join(", ")}:\n#{lines.join("\n")}"
  end
  puts groups.join("\n\n")
end

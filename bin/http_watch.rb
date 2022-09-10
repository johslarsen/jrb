#!/usr/bin/env ruby
require 'optparse'
require 'shellwords'
uri, = OptionParser.new do |o|
  o.banner += " URI"
  o.on "-d", "--[no-]differences", "Highlight the differences between successive updates."
  o.on "-r", "--root DIR", "Git repo to store the crawled site"
  o.on "-n", "--interval N", "Refresh every N seconds"
end.permute!(into: $opts ||= {})
dir = $opts.fetch(:root, "/tmp/http_cache")

# assuming caller have it in path to give more room to URI in watch title
cmd = ["http_crawl.rb", uri, "-cs", "-r", dir]
head = `git --git-dir=#{Shellwords.escape "#{dir}/.git"} rev-parse HEAD 2>&1`
cmd << "-h" << head if $? == 0

watch = ["watch", "-bxcn", $opts.fetch(:interval, 60).to_s]
watch << "-d" if $opts[:differences]
watch.concat cmd
exec(*watch)

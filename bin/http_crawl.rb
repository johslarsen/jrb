#!/usr/bin/env ruby

require_relative 'http_cache'
require_relative '../lib/critical_cmd'
require 'fileutils'

class HttpCrawler
  def initialize(toplevel = "/tmp/http_cache")
    @cache = HttpCache.new(toplevel)
    @toplevel = toplevel

    git_init(toplevel) unless Dir.exist? "#{@toplevel}/.git"
  end

  def get(uri, headers={})
    @cache.uncached(:Get, uri, headers)

    rpath = @cache.entry_relative(uri)
    critical_cmd("git", "add", "--", rpath, chdir: @toplevel)
    visable_changes = critical_cmd("git", "diff", "--cached", "--", rpath, chdir: @toplevel)
    if visable_changes.empty?
      critical_cmd("git", "reset", "--", rpath, chdir: @toplevel)
      nil
    else
      output = critical_cmd("git", "commit", "-m", "#{self.class}: Update #{uri}", chdir: @toplevel)
      output.lines[0].match(/([0-9a-f]+)\]/){|m| m[1]}
    end
  end

  def diff(uri, commit, opts: ["--color", "-U1"])
    system("git", "diff", *opts, commit, "--", @cache.entry_relative(uri), chdir: @toplevel)
  end

  private

  def git_init(repo)
    FileUtils.mkdir_p(repo)
    critical_cmd("git", "init", chdir: repo)
    File.open("#{@toplevel}/.gitattributes", "a") do |f|
      f.puts("* diff=w3m")
    end
    File.open("#{@toplevel}/.git/config", "a") do |f|
      f.puts <<EOF
[diff "w3m"]
    textconv = w3m -T text/html <
EOF
    end

    critical_cmd("git", "add", ".gitattributes", chdir: @toplevel)
    critical_cmd("git", "commit", "-m", "#{self.class}: Render HTML with w3m", chdir: @toplevel)
  end
end

if $0 == __FILE__
  require 'optparse'
  uri, _ = OptionParser.new do |o|
    o.banner += " URI"
    o.on "-r", "--root DIR", "Git repo to store the crawled site"
    o.on "-h", "--head HASH", "Fallback commit to diff with if site is unchanged"
    o.on "-U", "--unified N", "Display N lines of context before/after changes"
    o.on "-c", "--[no-]color", "Enable/disable diff output coloring"
    o.on "-s", "--[no-]status", "Exit 1 if site differ, 0 if not"
  end.permute!(into: $opts||={})
  crawler = HttpCrawler.new($opts.fetch(:root, "/tmp/http_cache"))
  commit = crawler.get(uri)
  origin = commit ? "#{commit}^" : $opts.fetch(:head, "").chomp
  unless origin.empty?
    diff_opts = ["-U#{$opts.fetch(:unified, 1)}"]
    diff_opts << "--color=#{$opts[:color] ? "always" : "none"}" if $opts.has_key? :color
    crawler.diff(uri, origin, opts: diff_opts)
  end
  if $opts[:status] && commit
    exit 1 # exit like diff to indicate that site differs from previous version
  end
end

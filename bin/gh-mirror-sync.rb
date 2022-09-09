#!/usr/bin/env ruby
require 'open3'
require 'json'
require 'uri'

class GhMirrorSync
  def initialize(root)
    @root = root
  end

  def sync(users)
    users.each do |user|
      repositories = self.class.list(user)
      repositories.each_with_index do |url, i|
        puts("#{user} %02d/%02d #{url}"%[i+1, repositories.length])
        path = "#{@root}/#{URI(url).path[1..-1]}.git"
        outerr, status = if File.exist?(path)
                           Open3.capture2e("git", "--git-dir=#{path}", "fetch", "--all")
                         else
                           Open3.capture2e("git", "clone", "--mirror", url, path)
                         end
        $stderr.puts(outerr) unless status.success?
      end
    end
  end

  def self.list(user)
    out, status = Open3.capture2("gh", "repo", "list", "-L1000", "--json", "url", user)
    if status.success?
      JSON.parse(out)
    else
      $stderr.puts("Failed to list repositories owned by #{user.inspect}")
      []
    end.map{|o| o["url"]}
  end

end

if $0 == __FILE__
  require 'optparse'
  users = OptionParser.new do |o|
    o.banner += " GITHUB_USER..."
    o.on("-C", "--directory DIR", "Put repository hierarchy into here")
  end.permute!(into: $opts||={})
  GhMirrorSync.new($opts.fetch(:directory, ".")).sync(users)
end

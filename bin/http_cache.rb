#!/usr/bin/env ruby

require 'date'
require 'fileutils'
require 'net/http'
require 'uri'

# Public: A simple HTTP(S) client that handle redirects and caches requests.
class HttpCache
  def initialize(toplevel="/tmp/http_cache")
    @toplevel = toplevel
  end

  def get(uri, headers={})
    cached(:Get, uri, headers).first
  end

  def cached(method, uri, headers={}, body=nil)
    path = entry(uri)
    return [File.read(path), nil] if valid_entry(path)
    res = uncached(method, uri, headers)
    [res.body, res]
  end

  def uncached(method, uri, headers={}, body=nil)
    original_uri = uri
    res = {"Location" => uri.to_s}
    begin
      uri = URI(res["Location"])
      Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        req = Net::HTTP.const_get(method).new(uri, headers)
        res = http.request(req, body)
      end
    end while res["Location"]
    update(res, original_uri)
  end

  def entry(uri)
    uri = uri.to_s =~ %r{://} ? URI(uri) : URI("http://#{uri}")
		"#{@toplevel}/#{uri.host.split(".").reverse.join(".")}/#{uri.path}?#{uri.query}"
  end
  def cached?(uri)
    File.exist? entry(uri)
  end
  def expired?(uri)
    !valid_entry(entry(uri))
  end

  private

  def valid_entry(entry)
    File.exist?(entry) && File.mtime(entry) >= Time.now
  end

  def update(response, original_uri)
    path = entry(response.uri)
    FileUtils.mkdir_p(File.dirname(path))
    open(path, "w") do |f|
      f.write(response.body)
    end
    File.utime(Time.now, expires(response), path)

    opath = entry(original_uri)
    if path != opath
      FileUtils.mkdir_p(File.dirname(opath))
      FileUtils.ln path, opath
    end

    response
  end

  DEFAULT_MAX_AGE = 60*60
  def expires(response)
    result = Time.now + DEFAULT_MAX_AGE
    if response["Expires"]
			result = begin
				DateTime.parse(response["Expires"]).to_time
			rescue ArgumentError
        Time.now
			end
    end
		if response["Cache-Control"]
      cc = response["Cache-Control"].strip.split(/\s*,\s*/).map do |kv|
        k, v = kv.split(/\s*=\s*/)
        [k, v]
      end.to_h

			if cc.has_key?("no-cache")
        result = Time.now
			else
				if cc["max-age"]
          result = Time.now + (cc["max-age"].to_i - response["Age"].to_i)
				end
			end
		end
		result
  end
end

if $0 == __FILE__
  require 'optparse'
  uri, _ = OptionParser.new{|o| o.banner += " <uri>"}.permute!
  puts HttpCache.new.get(uri)
end

#!/usr/bin/env ruby
require 'tmpdir'
require 'minitest/autorun'
require 'http_cache'

class HttpCacheTest < Minitest::Test
  DUMMY_URI = "http://example.com/path".freeze

  class Redirection
    def initialize(locations, headers = {})
      @locations = locations
      @headers = headers
    end

    def [](key)
      key == "Location" ? @locations.shift : @headers[key]
    end
  end

  def test_redirect
    mocked("foo", Redirection.new(["http://intermediary.com/other",
                                   "http://final.net/subdir/other"])) do |c, _, tmpdir|
      c.get(DUMMY_URI)
      assert_equal(["com.example", "com.example/path?",
                    "net.final", "net.final/subdir", "net.final/subdir/other?"],
                   Dir.glob("#{tmpdir}/**/*").map { |p| p.gsub(%r{^#{tmpdir}/}, "") }.to_a)
    end
  end

  def test_expire_default
    mocked("foo", {}) do |c, now|
      c.get(DUMMY_URI)
      assert_equal now + 60 * 60, File.mtime(c.entry(DUMMY_URI))
    end
  end

  def test_expire_expires
    a_time = Time.new(1970)
    mocked "foo", { "Expires" => a_time.to_s } do |c|
      c.get(DUMMY_URI)
      assert_equal a_time, File.mtime(c.entry(DUMMY_URI))
    end
  end

  def test_expire_max_age
    a_time = Time.new(2038, 1, 25)
    mocked "foo", { "Expires" => a_time.to_s, "Age" => 42, "Cache-Control" => "max-age=100" } do |c, now|
      c.get(DUMMY_URI)
      assert_equal now + 100 - 42, File.mtime(c.entry(DUMMY_URI))
    end
  end

  def test_expire_no_cache
    a_time = Time.new(2038, 1, 25)
    mocked "foo",
           { "Expires" => a_time.to_s, "Age" => 42, "Cache-Control" => " foo = bar , no-cache,max-age=100" } do |c, now|
      c.get(DUMMY_URI)
      assert_equal now, File.mtime(c.entry(DUMMY_URI))
    end
  end

  HTTP_CACHE_BIN = HttpCache.new("").public_method(:get).source_location[0]

  REAL_URI = "http://www.johslarsen.net/LICENSE.txt".freeze # and it redirects to https
  def test_real_and_cli
    Dir.mktmpdir do |tmpdir|
      c = HttpCache.new tmpdir
      original, res = c.cached(:Get, REAL_URI)
      assert File.exist? c.entry(REAL_URI)
      assert_equal original, File.read(c.entry(REAL_URI))
      assert_kind_of Net::HTTPOK, res

      cached, response_when_cached = c.cached(:Get, REAL_URI)
      assert_nil response_when_cached
      assert_equal original, cached

      assert_equal original, `#{HTTP_CACHE_BIN} #{REAL_URI}`
    end
  rescue StandardError, MiniTest::Assertion => e
    skip "Real request failed: #{e}"
  end

  private

  MockResponse = Struct.new :uri, :body, :headers do
    def [](key)
      headers[key]
    end
  end
  MockHttp = Struct.new :body, :headers do
    def request(req, _body = nil)
      MockResponse.new req.uri, body, headers
    end
  end
  def mocked(*mock_http_arg)
    Dir.mktmpdir do |tmpdir|
      Net::HTTP.stub(:start, nil, MockHttp.new(*mock_http_arg)) do
        now = Time.new(2038, 1, 20)
        Time.stub :now, now do
          yield HttpCache.new(tmpdir), now, tmpdir
        end
      end
    end
  end
end

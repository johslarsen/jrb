#!/usr/bin/env ruby
require 'optparse'
module OptionParserIntoBackport
  def order!(argv, into: nil, &nonopt)
    @backport_into ||= into
    super(argv, &nonopt)
  end

  def make_switch(opts, block = nil)
    @backport_into ||= nil
    if block.nil?
      m = opts[1]&.match(/^--([^ ]+)/)
      m ||= opts[0]&.match(/^-([^ ]+)/)
      block = ->(v) { @backport_into[m[1].to_sym] = v if @backport_into }
    end
    super(opts, block)
  end

  # Following methods are copies from https://ruby-doc.org/stdlib-2.6.3/libdoc/optparse/rdoc/OptionParser.html
  def permute!(argv = default_argv, into: nil)
    nonopts = []
    order!(argv, into: into, &nonopts.method(:<<))
    argv[0, 0] = nonopts
    argv
  end

  def parse!(argv = default_argv, into: nil)
    if ENV.include?('POSIXLY_CORRECT')
      order!(argv, into: into)
    else
      permute!(argv, into: into)
    end
  end

  def order(*argv, into: nil, &nonopt)
    argv = argv[0].dup if argv.size == 1 && argv[0].is_a?(Array)
    order!(argv, into: into, &nonopt)
  end

  def permute(*argv, into: nil)
    argv = argv[0].dup if argv.size == 1 && argv[0].is_a?(Array)
    permute!(argv, into: into)
  end

  def parse(*argv, into: nil)
    argv = argv[0].dup if argv.size == 1 && argv[0].is_a?(Array)
    parse!(argv, into: into)
  end
end

class OptionParser
  prepend OptionParserIntoBackport
end

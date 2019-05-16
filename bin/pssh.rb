#!/usr/bin/env ruby
require 'tmpdir'
require 'tempfile'

# Public: Parallel ssh execution
class PSSH
  def initialize(hosts, ssh_opts: ["-q", "-oBatchMode=yes"])
    @hosts = hosts
    @ssh_opts = ssh_opts
  end

  # Public: Execute this command, and put one output file per host in
  # output_dir (or a tmpdir if nil)
  #
  # Returns output_dir.
  def execute(cmd, output_dir: nil, stdin: nil, &host_finished)
    output_dir ||= Dir.mktmpdir("pssh")
    host_finished ||= Proc.new do |path,status|
      $stderr.puts("#{path}: #{status==0? "Success" : "Failed #{status}"}")
    end
    run_in_parallel(cmd, output_dir, stdin: stdin, &host_finished)
    output_dir
  end

  # Public: Execute this command, and write host prefixed lines to stdout.
  def stdout(cmd, stdout: $stdout, stdin: nil)
    Dir.mktmpdir("pssh") do |dir|
      execute(cmd, output_dir: dir, stdin: stdin) do |path,status|
        host = File.basename path
        $stderr.puts("#{host}: #{status==0? "Success" : "Failed #{status}"}")
        File.open(path) do |f|
          f.each_line do |l|
            stdout.print("#{host}: #{l}")
          end
        end
      end
    end
  end

  protected

  def run_in_parallel(cmd, dir, stdin: nil, &host_finished)
    pgroup = nil
    pid2host = @hosts.map do |host|
      outerr = File.join dir, host
      ssh = ['ssh', *@ssh_opts, host, cmd]
      pid = Process.spawn(*ssh, pgroup: pgroup, in: stdin||:close, out: outerr, err: outerr)
      pgroup ||= Process.getpgid(pid)
      [pid, host]
    end.to_h
    until pid2host.empty?
      pid, status = Process.wait2(-pgroup)
      host = pid2host.delete pid
      host_finished.call(File.join(dir, host), status)
    end
  end

end

if $0 == __FILE__
  require 'optparse'
  OptionParser.new do |o|
    o.banner << " HOST... [CMD]"
    o.on("-f", "--file PATH", "Instead of CMD, execute this script remotely")
    o.on("-a", "--file-argument ARGS", "Arguments called to the remote -f script")
  end.permute!(ARGV, into: $opts={})
  hosts, pssh_args = if $opts[:file]
    s = "/tmp/pssh_$$.sh"
    cmd = "cat > #{s}; chmod +x #{s}; #{s} #{$opts[:"file-argument"]}"
    [ARGV, [cmd, stdin: $opts[:file]]]
  else
    [ARGV[0..-2], [ARGV[-1]]]
  end
  pssh = PSSH.new(hosts)
  pssh.stdout(*pssh_args)
end

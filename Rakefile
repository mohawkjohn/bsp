# -*- ruby -*-

require 'rubygems'
require 'rubygems/package_task'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'

task :console do |task|
  cmd = [ 'irb', "-r './lib/bsp.rb'" ]
  run *cmd
end

task :pry do |task|
  cmd = [ 'pry', "-r './lib/bsp.rb'" ]
  run *cmd
end

namespace :pry do
  task :valgrind => [ :compile ] do |task|
    cmd  = [ 'valgrind' ] + VALGRIND_OPTIONS
    cmd += ['ruby', '-Ilib:ext', "-r './lib/bsp.rb'", "-r 'pry'", "-e 'binding.pry'"]
    run *cmd
  end
end

namespace :console do
  CONSOLE_CMD = ['irb', "-r './lib/bsp.rb'"]
  desc "Run console under GDB."
  task :gdb => [ :compile ] do |task|
          cmd = [ 'gdb' ] + GDB_OPTIONS
          cmd += [ '--args' ]
          cmd += CONSOLE_CMD
          run( *cmd )
  end

end

task :default => :spec

def run *cmd
  sh(cmd.join(" "))
end

# vim: syntax=ruby

require 'rubygems'  # poor people still on 1.8
gem 'redis', '>= 3.0.0'
require 'redis'

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'bacon'
Bacon.summary_at_exit
if $0 =~ /\brspec$/
  raise "\n===\nThese tests are in bacon, not rspec.  Try: bacon #{ARGV * ' '}\n===\n"
end

REDIS_CLASS_NAMES = [:Counter, :HashKey, :List, :Lock, :Set, :SortedSet, :Value]

UNIONSTORE_KEY = 'test:unionstore'
INTERSTORE_KEY = 'test:interstore'
DIFFSTORE_KEY  = 'test:diffstore'

# Start our own redis-server to avoid corrupting any others
REDIS_BIN  = 'redis-server'
REDIS_PORT = ENV['REDIS_PORT'] || 9212
REDIS_HOST = ENV['REDIS_HOST'] || 'localhost'
REDIS_PID  = 'redis.pid'  # can't be absolute
REDIS_DUMP = 'redis.rdb'  # can't be absolute
REDIS_RUNDIR = File.dirname(__FILE__)

def start_redis
  puts "=> Starting redis-server on #{REDIS_HOST}:#{REDIS_PORT}"
  fork_pid = fork do
    system "cd #{REDIS_RUNDIR} && (echo port #{REDIS_PORT}; " +
           "echo logfile /dev/null; echo daemonize yes; " +
           "echo pidfile #{REDIS_PID}; echo dbfilename #{REDIS_DUMP}; " +
           "echo databases 32) | #{REDIS_BIN} -"
  end
  fork_pid.should > 0
  sleep 2
end

def kill_redis
  pidfile = File.expand_path REDIS_PID,  REDIS_RUNDIR
  rdbfile = File.expand_path REDIS_DUMP, REDIS_RUNDIR
  pid = File.read(pidfile).to_i
  puts "=> Killing #{REDIS_BIN} with pid #{pid}"
  Process.kill "TERM", pid
  Process.kill "KILL", pid
  File.unlink pidfile
  File.unlink rdbfile if File.exists? rdbfile
end

# Start redis-server except under JRuby
unless defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
  start_redis

  at_exit do
    kill_redis
  end
end

def raises_exception(&block)
  e = nil
  begin
    block.call
  rescue => e
  end
  e.should.be.is_a?(StandardError)
end

# Grab a global handle
REDIS_HANDLE = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
#$redis = REDIS_HANDLE
Redis.current = REDIS_HANDLE

SORT_ORDER = {:order => 'desc alpha'}
SORT_LIMIT = {:limit => [2, 2]}
SORT_BY    = {:by => 'm_*'}
SORT_GET   = {:get => 'spec/*/sorted'}.merge!(SORT_LIMIT)
SORT_STORE = {:store => "spec/aftersort"}.merge!(SORT_GET)

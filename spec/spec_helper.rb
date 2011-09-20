require 'rubygems'  # poor people still on 1.8
gem 'redis', '>= 2.1.1'
require 'redis'

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'bacon'
Bacon.summary_at_exit

UNIONSTORE_KEY = 'test:unionstore'
INTERSTORE_KEY = 'test:interstore'
DIFFSTORE_KEY  = 'test:diffstore'

# Start our own redis-server to avoid corrupting any others
REDIS_BIN  = 'redis-server'
REDIS_PORT = ENV['REDIS_PORT'] || 9212
REDIS_HOST = ENV['REDIS_HOST'] || 'localhost'
REDIS_PID  = File.expand_path 'redis.pid', File.dirname(__FILE__)
REDIS_DUMP = File.expand_path 'redis.rdb', File.dirname(__FILE__)
puts "=> Starting redis-server on #{REDIS_HOST}:#{REDIS_PORT}"
fork_pid = fork do
  system "(echo port #{REDIS_PORT}; echo logfile /dev/null; echo daemonize yes; echo pidfile #{REDIS_PID}; echo dbfilename #{REDIS_DUMP}) | #{REDIS_BIN} -"
end
at_exit do
  pid = File.read(REDIS_PID).to_i
  puts "=> Killing #{REDIS_BIN} with pid #{pid}"
  Process.kill "TERM", pid
  Process.kill "KILL", pid
  File.unlink REDIS_PID, REDIS_DUMP
end

# Grab a global handle
$redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)

SORT_ORDER = {:order => 'desc alpha'}
SORT_LIMIT = {:limit => [2, 2]}
SORT_BY = {:by => 'm_*'}
SORT_GET = {:get => 'spec/*/sorted'}.merge!(SORT_LIMIT)
SORT_STORE = {:store => "spec/aftersort"}.merge!(SORT_GET)

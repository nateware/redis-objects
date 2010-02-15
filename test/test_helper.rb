dir = File.dirname(File.expand_path(__FILE__))

require 'rubygems'
require 'test/unit'
require File.join(dir, '../lib/redis/objects')

# Trigger autoload
Redis::Objects::Locks
Redis::Objects::Lists
Redis::Objects::Sets
Redis::Objects::Counters
Redis::Objects::Locks



# make sure we can run redis
if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end

# start our own redis when the tests start, kill it when they end
at_exit do
  next if $!

  exit_code = Test::Unit::AutoRunner.run

  pid = `ps -e -o pid,command | grep [r]edis-test`.split(" ")[0]
  puts "Killing test redis server..."
  `rm -f #{dir}/dump.rdb`
  Process.kill("KILL", pid.to_i)
  exit exit_code
end

puts "Starting redis for testing at localhost:9736..."
`redis-server #{dir}/redis-test.conf`
$redis = Redis.new(:host => 'localhost', :port => 9736)
Redis::Objects.redis = $redis

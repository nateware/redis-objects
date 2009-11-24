$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'redis'
require 'redis/objects'

Redis::Objects.redis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'])

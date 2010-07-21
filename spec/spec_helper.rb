$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'redis'

require 'rubygems'  # poor people still on 1.8
require 'bacon'
Bacon.summary_at_exit

$redis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'])

UNIONSTORE_KEY = 'test:unionstore'
INTERSTORE_KEY = 'test:interstore'
DIFFSTORE_KEY  = 'test:diffstore'

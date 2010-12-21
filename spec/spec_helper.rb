require 'rubygems'  # poor people still on 1.8
gem 'redis', '>= 2.1.1'
require 'redis'

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'bacon'
Bacon.summary_at_exit

$redis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'])

UNIONSTORE_KEY = 'test:unionstore'
INTERSTORE_KEY = 'test:interstore'
DIFFSTORE_KEY  = 'test:diffstore'


SORT_ORDER = {:order => 'desc alpha'}
SORT_LIMIT = {:limit => [2, 2]}
SORT_BY = {:by => 'm_*'}
SORT_GET = {:get => 'spec/*/sorted'}.merge!(SORT_LIMIT)
SORT_STORE = {:store => "spec/aftersort"}.merge!(SORT_GET)



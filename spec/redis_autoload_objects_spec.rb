
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

# tests whether autoload functionality works correctly; had issues previously

require 'redis/objects'
# $redis used automatically

describe 'Redis::Objects' do
  it "should autoload everything" do
    defined?(::Redis::Counter).should == "constant"
    x = Redis::Counter.new('x')
    x.class.name.should == "Redis::Counter"
    x.redis.should == REDIS_HANDLE

    defined?(::Redis::HashKey).should == "constant"
    x = Redis::HashKey.new('x')
    x.class.name.should == "Redis::HashKey"
    x.redis.should == REDIS_HANDLE

    defined?(::Redis::List).should == "constant"
    x = Redis::List.new('x')
    x.class.name.should == "Redis::List"
    x.redis.should == REDIS_HANDLE

    defined?(::Redis::Lock).should == "constant"
    x = Redis::Lock.new('x')
    x.class.name.should == "Redis::Lock"
    x.redis.should == REDIS_HANDLE

    defined?(::Redis::Set).should == "constant"
    x = Redis::Set.new('x')
    x.class.name.should == "Redis::Set"
    x.redis.should == REDIS_HANDLE

    defined?(::Redis::SortedSet).should == "constant"
    x = Redis::SortedSet.new('x')
    x.class.name.should == "Redis::SortedSet"
    x.redis.should == REDIS_HANDLE

    defined?(::Redis::Value).should == "constant"
    x = Redis::Value.new('x')
    x.class.name.should == "Redis::Value"
    x.redis.should == REDIS_HANDLE
  end
end

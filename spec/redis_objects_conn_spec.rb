#
# Connection tests - a bit ugly but important
#
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'
require 'connection_pool'

BAD_REDIS = "totally bad bogus redis handle"

# Grab a global handle
describe 'Connection tests' do
  it "should support overriding object handles with a vanilla redis connection" do
    class CustomConnectionObject
      include Redis::Objects

      def id
        return 1
      end

      redis_handle = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT, :db => 31)
      value :redis_value, :redis => redis_handle, :key => 'rval'
      value :default_redis_value, :key => 'rval'
    end

    obj = CustomConnectionObject.new

    obj.default_redis_value.value.should == nil
    obj.redis_value.value.should == nil

    obj.default_redis_value.value = 'foo'
    obj.default_redis_value.value.should == 'foo'
    obj.redis_value.value.should == nil

    obj.default_redis_value.clear
    obj.redis_value.value = 'foo'
    obj.redis_value.value.should == 'foo'
    obj.default_redis_value.value.should == nil

    obj.redis_value.clear
    obj.default_redis_value.clear
  end

  it "should support mget" do
    class CustomConnectionObject
      include Redis::Objects

      def id
        return 1
      end

      redis_handle = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT, :db => 31)
      value :redis_value, :key => 'rval'
    end

    obj = CustomConnectionObject.new

    obj.redis_value.value = 'foo'

    obj.class.mget(:redis_value, []).should == []
    obj.class.mget(:redis_value, [obj]).should == ['foo']

    obj.redis_value.clear
  end

  it "should support overriding object handles with a connection_pool" do
    class CustomConnectionObject
      include Redis::Objects

      def id
        return 1
      end

      redis_handle = ConnectionPool.new { Redis.new(:host => REDIS_HOST, :port => REDIS_PORT, :db => 31) }
      value :redis_value, :redis => redis_handle, :key => 'rval'
      value :default_redis_value, :key => 'rval'
    end

    obj = CustomConnectionObject.new

    obj.default_redis_value.value.should == nil
    obj.redis_value.value.should == nil

    obj.default_redis_value.value = 'foo'
    obj.default_redis_value.value.should == 'foo'
    obj.redis_value.value.should == nil

    obj.default_redis_value.clear
    obj.redis_value.value = 'foo'
    obj.redis_value.value.should == 'foo'
    obj.default_redis_value.value.should == nil

    obj.redis_value.clear
    obj.default_redis_value.clear
  end

  it "should support local handles with a vanilla redis connection" do
    Redis.current = nil  # reset from other tests
    Redis::Objects.redis = nil
    @redis_handle = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)

    # Redis.current is lazily auto-populated to touch 6379
    # This why we choose the weird 9212 port to avoid
    Redis.current.inspect.should == Redis.new.inspect
    Redis::Objects.redis.inspect.should == Redis.new.inspect

    v = Redis::Value.new('conn/value', @redis_handle)
    v.clear
    v.value = 'yay'
    v.value.should == 'yay'

    h = Redis::HashKey.new('conn/hash', @redis_handle)
    h.clear
    h['k'] = 'v'

    l = Redis::List.new('conn/list', @redis_handle)
    l.clear
    l << 3
    l << 4
    l << 5

    s = Redis::Set.new('conn/set', @redis_handle)
    s.clear
    s << 5
    s << 5
    s << 6
    s << 7

    z = Redis::SortedSet.new('conn/zset', @redis_handle)
    z.clear
    z['a'] = 8
    z['b'] = 7
    z['c'] = 9
    z['d'] = 6

    c = Redis::Counter.new('conn/counter', @redis_handle)
    c.reset
    c.incr(3)
    c.decr(1)
  end

  it "should support local handles with a connection_pool" do
    Redis.current = nil  # reset from other tests
    Redis::Objects.redis = nil
    @redis_handle = ConnectionPool.new { Redis.new(:host => REDIS_HOST, :port => REDIS_PORT) }

    # Redis.current is lazily auto-populated to touch 6379
    # This why we choose the weird 9212 port to avoid
    Redis.current.inspect.should == Redis.new.inspect
    Redis::Objects.redis.inspect.should == Redis.new.inspect

    v = Redis::Value.new('conn/value', @redis_handle)
    v.clear
    v.value = 'yay'
    v.value.should == 'yay'

    h = Redis::HashKey.new('conn/hash', @redis_handle)
    h.clear
    h['k'] = 'v'

    l = Redis::List.new('conn/list', @redis_handle)
    l.clear
    l << 3
    l << 4
    l << 5

    s = Redis::Set.new('conn/set', @redis_handle)
    s.clear
    s << 5
    s << 5
    s << 6
    s << 7

    z = Redis::SortedSet.new('conn/zset', @redis_handle)
    z.clear
    z['a'] = 8
    z['b'] = 7
    z['c'] = 9
    z['d'] = 6

    c = Redis::Counter.new('conn/counter', @redis_handle)
    c.reset
    c.incr(3)
    c.decr(1)
  end

  it "should support Redis.current" do
    Redis.current = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)

    Redis::Value.new('conn/value').should == 'yay'
    Redis::HashKey.new('conn/hash').keys.should == ['k']
    Redis::List.new('conn/list').sort.should  == ['3', '4', '5']
    Redis::Set.new('conn/set').sort.should    == ['5', '6', '7']
    Redis::SortedSet.new('conn/zset').should  == ['d', 'b', 'a', 'c']
    Redis::Counter.new('conn/counter').should == 2
  end

  it "should support Redis::Objects.redis= with a connection_pool" do
    @redis_handle = ConnectionPool.new { Redis.new(:host => REDIS_HOST, :port => REDIS_PORT) }

    # Redis.current is lazily auto-populated to touch 6379
    # This why we choose the weird 9212 port to avoid
    Redis.current = BAD_REDIS
    Redis::Objects.redis.should == BAD_REDIS

    # This set of tests sucks, it fucks up the per-data-type handles
    # because Redis.current is then set to a BS value, and the lazy
    # init code in redis-rb will keep that value until we clear it.
    # This ends up fucking any sequential tests.
    raises_exception{ Redis::Value.new('conn/value').should.be.nil       }
    raises_exception{ Redis::HashKey.new('conn/hash').keys.should == []  }
    raises_exception{ Redis::List.new('conn/list').sort.should == []     }
    raises_exception{ Redis::Set.new('conn/set').sort.should == []       }
    raises_exception{ Redis::SortedSet.new('conn/zset').should == []     }
    raises_exception{ Redis::Counter.new('conn/counter').get.should == 0 }

    Redis::Objects.redis = @redis_handle
    Redis::Value.new('fart').redis.is_a?(Redis::Objects::ConnectionPoolProxy).should == true

    # These should now get the correct handle
    Redis::Value.new('conn/value').should == 'yay'
    Redis::HashKey.new('conn/hash').keys.should == ['k']
    Redis::List.new('conn/list').sort.should  == ['3', '4', '5']
    Redis::Set.new('conn/set').sort.should    == ['5', '6', '7']
    Redis::SortedSet.new('conn/zset').should  == ['d', 'b', 'a', 'c']
    Redis::Counter.new('conn/counter').should == 2

  end

  it "should support Redis::Objects.redis= with a vanilla redis connection" do
    # reset redis
    Redis::Objects.redis = nil
    @redis_handle = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)

    # Redis.current is lazily auto-populated to touch 6379
    # This why we choose the weird 9212 port to avoid
    Redis.current = BAD_REDIS
    Redis::Objects.redis.should == BAD_REDIS

    # This set of tests sucks, it fucks up the per-data-type handles
    # because Redis.current is then set to a BS value, and the lazy
    # init code in redis-rb will keep that value until we clear it.
    # This ends up fucking any sequential tests.
    raises_exception{ Redis::Value.new('conn/value').should.be.nil       }
    raises_exception{ Redis::HashKey.new('conn/hash').keys.should == []  }
    raises_exception{ Redis::List.new('conn/list').sort.should == []     }
    raises_exception{ Redis::Set.new('conn/set').sort.should == []       }
    raises_exception{ Redis::SortedSet.new('conn/zset').should == []     }
    raises_exception{ Redis::Counter.new('conn/counter').get.should == 0 }

    Redis::Objects.redis = @redis_handle
    Redis::Value.new('fart').redis.should == @redis_handle

    # These should now get the correct handle
    Redis::Value.new('conn/value').should == 'yay'
    Redis::HashKey.new('conn/hash').keys.should == ['k']
    Redis::List.new('conn/list').sort.should  == ['3', '4', '5']
    Redis::Set.new('conn/set').sort.should    == ['5', '6', '7']
    Redis::SortedSet.new('conn/zset').should  == ['d', 'b', 'a', 'c']
    Redis::Counter.new('conn/counter').should == 2

    # Fix for future tests
    Redis.current = @redis_handle
  end

  it "should support pipelined changes" do
    list = Redis::List.new('pipelined/list')
    key = Redis::HashKey.new('pipelined/hash')
    Redis::Objects.redis.pipelined do
      key['foo'] = 'bar'
      list.push 1, 2
    end
    key.all.should == { 'foo' => 'bar' }
    list.values.should == %w[1 2]
  end
end

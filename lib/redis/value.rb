class Redis
  #
  # Class representing a simple value.  You can use standard Ruby operations on it.
  #
  class Value
    require 'redis/serialize'
    include Redis::Serialize

    attr_reader :key, :options, :redis
    def initialize(key, redis=$redis, options={})
      @key = key
      @redis = redis
      @options = options
      @redis.setnx(key, @options[:default]) if @options[:default]
    end

    def value=(val)
      redis.set(key, to_redis(val))
    end
    
    def value
      from_redis redis.get(key)
    end
    alias_method :get, :value

    def delete
      redis.del(key)
    end
    alias_method :del, :delete

    def to_s;  value.to_s; end
    alias_method :to_str, :to_s

    def ==(x); value == x; end
    def nil?;  value.nil?; end
  end
end
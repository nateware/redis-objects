class Redis
  #
  # Class representing a Redis list.  Instances of Redis::List are designed to 
  # behave as much like Ruby arrays as possible.
  #
  class List
    attr_reader :key, :options, :redis
    def initialize(key, options={})
      @key = key
      @options = options
      @redis   = options[:redis] || $redis || Redis::Objects.redis
      @options[:start] ||= 0
      @options[:type]  ||= @options[:start] == 0 ? :increment : :decrement
      @redis.setnx(key, @options[:start]) unless @options[:start] == 0 || @options[:init] === false
    end
    
    def <<(value)
      push(value)
    end
    
    def push(value)
      @redis.rpush(key, value.to_redis)
    end

    def unshift(value)
      redis.lpush(key, value.to_redis)
      @values.unshift value
    end

    def values
      @values ||= get
    end

    def value=(val)
      redis.set(key, val)
      @values = val
    end
    
    def get
      @values = lrange(key,0,-1)
    end
    
    def lrange(start_index, end_index)
      redis.lrange(key, start_index, end_index)
    end
    
    def length
      redis.length
    end
    alias_method :size, :length
  end
end
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
      self  # for << 'a' << 'b'
    end
    
    def push(value)
      redis.rpush(key, value)
      @values << value
    end

    def pop
      redis.rpop(key)
      @values.pop
    end

    def unshift(value)
      redis.lpush(key, value)
      @values.unshift value
    end

    def shift
      redis.lpop(key)
      @values.shift
    end

    def values
      @values ||= get
    end

    def value=(val)
      redis.set(key, val)
      @values = val
    end
    
    def get
      @values = range(0, -1)
    end
    
    def [](index, length=nil)
      case index
      when Range
        range(index.first, index.last)
      else
        range(index, length || index)
      end
    end
    
    def delete(name, count=0)
      redis.lrem(key, count, name)  # weird api
      get
    end

    def range(start_index, end_index)
      redis.lrange(key, start_index, end_index)
    end
 
    def at(index)
      redis.lrange(key, index, index)
    end

    def last
      redis.lrange(key, -1, -1)
    end

    def clear
      redis.del(key)
      @values = []
    end

    def length
      redis.llen(key)
    end
    alias_method :size, :length
    
    def empty?
      values.empty?
    end
 
    def ==(x)
      values == x
    end
  end
end
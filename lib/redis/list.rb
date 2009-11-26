class Redis
  #
  # Class representing a Redis list.  Instances of Redis::List are designed to 
  # behave as much like Ruby arrays as possible.
  #
  class List
    require 'enumerator'
    include Enumerable

    attr_reader :key, :options, :redis
    def initialize(key, redis=$redis, options={})
      @key = key
      @redis = redis
      @options = options
    end
    
    # Works like push.  Can chain together: list << 'a' << 'b'
    def <<(value)
      push(value)
      self  # for << 'a' << 'b'
    end

    # Add a member to the end of the list. Redis: RPUSH
    def push(value)
      redis.rpush(key, value)
    end

    # Remove a member from the end of the list. Redis: RPOP
    def pop
      redis.rpop(key)
    end

    # Add a member to the start of the list. Redis: LPUSH
    def unshift(value)
      redis.lpush(key, value)
    end

    # Remove a member from the start of the list. Redis: LPOP
    def shift
      redis.lpop(key)
    end

    # Return all values in the list. Redis: LRANGE(0,-1)
    def values
      range(0, -1)
    end
    alias_method :get, :values

    # Same functionality as Ruby arrays.  If a single number is given, return
    # just the element at that index using Redis: LINDEX. Otherwise, return
    # a range of values using Redis: LRANGE.
    def [](index, length=nil)
      if index.is_a? Range
        range(index.first, index.last)
      elsif length
        range(index, length)
      else
        at(index)
      end
    end
    
    def delete(name, count=0)
      redis.lrem(key, count, name)  # weird api
      get
    end

    def each(&block)
      values.each(&block)
    end

    def range(start_index, end_index)
      redis.lrange(key, start_index, end_index)
    end

    # Return the value at the given index.
    def at(index)
      redis.lindex(key, index)
    end

    def last
      redis.lrange(key, -1, -1)
    end

    def clear
      redis.del(key)
    end

    def length
      redis.llen(key)
    end
    alias_method :size, :length
    
    def empty?
      length == 0
    end
 
    def ==(x)
      values == x
    end
    
    def to_s
      values.join(', ')
    end
  end
end
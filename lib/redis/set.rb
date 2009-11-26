class Redis
  #
  # Class representing a set.
  #
  class Set
    require 'enumerator'
    include Enumerable

    attr_reader :key, :options, :redis
    def initialize(key, redis=$redis, options={})
      @key = key
      @redis = redis
      @options = options
    end

    # Works like add.  Can chain together: list << 'a' << 'b'
    def <<(value)
      add(value)
      self  # for << 'a' << 'b'
    end
    
    # Add the specified value to the set only if it does not exist already.
    # Redis: SADD
    def add(value)
      redis.sadd(key, value)
    end

    # Return all members in the set.  Redis: SMEMBERS
    def members
      redis.smembers(key)
    end
    alias_method :get, :members

    # Returns true if the specified value is in the set.  Redis: SISMEMBER
    def member?(value)
      redis.sismember(key, value)
    end

    # Delete the value from the set.  Redis: SREM
    def delete(name)
      redis.srem(key, name)
      get
    end

    # Wipe the set entirely.  Redis: DEL
    def clear
      redis.del(key)
    end

    # Iterate through each member of the set.  Redis::Objects mixes in Enumerable,
    # so you can also use familiar methods like +collect+, +detect+, and so forth.
    def each(&block)
      members.each(&block)
    end

    # The number of members in the set. Aliased as size. Redis: SCARD
    def length
      redis.scard(key)
    end
    alias_method :size, :length

    # Returns true if the set has no members. Redis: SCARD == 0
    def empty?
      length == 0
    end

    def ==(x)
      members == x
    end
    
    def to_s
      members.join(', ')
    end
  end
end
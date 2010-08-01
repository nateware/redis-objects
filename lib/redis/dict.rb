class Redis
  #
  # Class representing a Dict (Redis Hash)
  #
  class Dict
    require 'enumerator'
    include Enumerable
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands
    require 'redis/helpers/serialize'
    include Redis::Helpers::Serialize
    
    attr_reader :key, :redis

    # Create a new Dict.
    def initialize(key, *args)
      @key = key.is_a?(Array) ? key.flatten.join(':') : key
      @redis = args.first || $redis
    end

    # Sets a field to value
    def []=(field, value)
      store(field, value)
    end

    # Gets the value of a field
    def [](field)
      fetch(field)
    end

    # Redis: HSET
    def store(field, value)
      redis.hset(key, field, value)
    end

    # Redis: HGET
    def fetch(field)
      redis.hget(key, field)
    end

    # Verify that a field exists. Redis: HEXISTS
    def has_key?(field)
      redis.hexists(key, field)
    end
    alias_method :include?, :has_key?
    alias_method :key?, :has_key?
    alias_method :member?, :has_key?

    # Delete field. Redis: HDEL
    def delete(field)
      redis.hdel(key, field)
    end

    # Enumerate through all fields. Redis: HGETALL
    def each
      redis.hgetall(key)
    end

    # Enumerate through all keys. Redis: HKEYS
    def each_key
      redis.hkeys(key)
    end

    # Enumerate through all values. Redis: HVALS
    def each_value
      redis.hvals(key)
    end

    # Return the size of the dict. Redis: HLEN
    def size
      redis.hlen(key)
    end
    alias_method :length, :size
    alias_method :count, :size

    # Returns true if dict is empty
    def empty?
      true if size == 0
    end

    # Clears the dict of all keys/values. Redis: DEL
    def clear
      redis.del(key)
    end

    # Set keys in bulk, takes a hash of field/values {'field1' => 'val1'}. Redis: HMSET
    def bulk_set(hsh)
      redis.hmset(key, *hsh)
    end
    
    # Get keys in bulk, takes fields as arguments. Redis: HMGET
    def bulk_get(*fields)
      hsh = {}
      res = redis.hmget(key, *fields)
      fields.each do |k|
        hsh[k] = res.shift
      end
      hsh
    end
    
    # Increment value by integer at field. Redis: HINCRBY
    def incr(field, val = 1)
      redis.hincrby(key, field, val)
    end

  end
end


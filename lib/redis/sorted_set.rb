class Redis
  #
  # Class representing a sorted set.
  #
  class SortedSet
    require 'enumerator'
    include Enumerable
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands
    require 'redis/helpers/serialize'
    include Redis::Helpers::Serialize

    attr_reader :key, :options, :redis
    
    # Create a new SortedSet.
    def initialize(key, redis=$redis, options={})
      @key = key
      @redis = redis
      @options = options
    end

    # How to add values using a sorted set.  The first argument is the score,
    # just like the first argument to ZADD.
    def []=(score, value)
      redis.zadd(key, score, to_redis(value))
    end

    # Same functionality as Ruby arrays.  If a single number is given, return
    # just the element at that index using Redis: LINDEX. Otherwise, return
    # a range of values using Redis: LRANGE.
    def [](index, length=nil)
      if index.is_a? Range
        range(index.first, index.last)
      elsif length
        range(index, length)
      else
        raise ArgumentError, "Missing [index, length] for SortedSet range"
      end
    end

    # Return a range of values from +start_index+ to +end_index+.  Can also use
    # the familiar list[start,end] Ruby syntax. Redis: ZRANGE
    def range(start_index, end_index, with_scores=false)
      from_redis redis.zrange(key, start_index, end_index, with_scores)
    end

    # Return a range of values from +start_index+ to +end_index+ in reverse order. Redis: ZREVRANGE
    def revrange(start_index, end_index, with_scores=false)
      from_redis redis.zrange(key, start_index, end_index, with_scores)
    end

    # The number of members in the set. Aliased as size. Redis: ZCARD
    def length
      redis.zcard(key)
    end
    alias_method :size, :length

    # Delete the value from the set.  Redis: ZREM
    def delete(value)
      redis.zrem(key, value)
    end

    # Increment the rank of that member atomically and return the new value. This
    # method is aliased as incr() for brevity. Redis: ZINCRBY
    def increment(by=1)
      redis.zincrby(key, by).to_i
    end
    alias_method :incr, :increment
    alias_method :incrby, :increment

    # Convenience to calling increment() with a negative number. 
    def decrement(by=-1)
      redis.zincrby(key, by).to_i
    end
    alias_method :decr, :decrement
    alias_method :decrby, :decrement

    # Return the intersection with another set.  Can pass it either another set
    # object or set name.  Also available as & which is a bit cleaner:
    #
    #    members_in_both = set1 & set2
    #
    # If you want to specify multiple sets, you must use +intersection+:
    #
    #    members_in_all = set1.intersection(set2, set3, set4)
    #    members_in_all = set1.inter(set2, set3, set4)  # alias
    #
    # Redis: SINTER
    def intersection(*sets)
      from_redis redis.sinter(key, *keys_from_objects(sets))
    end
    alias_method :intersect, :intersection
    alias_method :inter, :intersection
    alias_method :&, :intersection
    
    # Calculate the intersection and store it in Redis as +name+. Returns the number
    # of elements in the stored intersection. Redis: SUNIONSTORE
    def interstore(name, *sets)
      redis.sinterstore(name, key, *keys_from_objects(sets))
    end

    # Return the union with another set.  Can pass it either another set
    # object or set name. Also available as | and + which are a bit cleaner:
    #
    #    members_in_either = set1 | set2
    #    members_in_either = set1 + set2
    #
    # If you want to specify multiple sets, you must use +union+:
    #
    #    members_in_all = set1.union(set2, set3, set4)
    #
    # Redis: SUNION
    def union(*sets)
      from_redis redis.sunion(key, *keys_from_objects(sets))
    end
    alias_method :|, :union
    alias_method :+, :union

    # Calculate the union and store it in Redis as +name+. Returns the number
    # of elements in the stored union. Redis: SUNIONSTORE
    def unionstore(name, *sets)
      redis.sunionstore(name, key, *keys_from_objects(sets))
    end

    # Return the difference vs another set.  Can pass it either another set
    # object or set name. Also available as ^ or - which is a bit cleaner:
    #
    #    members_difference = set1 ^ set2
    #    members_difference = set1 - set2
    #
    # If you want to specify multiple sets, you must use +difference+:
    #
    #    members_difference = set1.difference(set2, set3, set4)
    #    members_difference = set1.diff(set2, set3, set4)
    #
    # Redis: SDIFF
    def difference(*sets)
      from_redis redis.sdiff(key, *keys_from_objects(sets))
    end
    alias_method :diff, :difference
    alias_method :^, :difference
    alias_method :-, :difference

    # Calculate the diff and store it in Redis as +name+. Returns the number
    # of elements in the stored union. Redis: SDIFFSTORE
    def diffstore(name, *sets)
      redis.sdiffstore(name, key, *keys_from_objects(sets))
    end

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
    
    private
    
    def keys_from_objects(sets)
      raise ArgumentError, "Must pass in one or more set names" if sets.empty?
      sets.collect{|set| set.is_a?(Redis::SortedSet) ? set.key : set}
    end
    
  end
end
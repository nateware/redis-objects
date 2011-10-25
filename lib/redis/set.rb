require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a set.
  #
  class Set < BaseObject
    require 'enumerator'
    include Enumerable
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands
    require 'redis/helpers/serialize'
    include Redis::Helpers::Serialize

    attr_reader :key, :options, :redis

    # Works like add.  Can chain together: list << 'a' << 'b'
    def <<(value)
      add(value)
      self  # for << 'a' << 'b'
    end

    # Add the specified value to the set only if it does not exist already.
    # Redis: SADD
    def add(value)
      redis.sadd(key, to_redis(value))
    end

    # Remove and return a random member.  Redis:SPOP
    def pop
      from_redis redis.spop(key)
    end

    # Return all members in the set.  Redis: SMEMBERS
    def members
      v = from_redis redis.smembers(key)
      v.nil? ? [] : v
    end
    alias_method :get, :members

    # Returns true if the specified value is in the set.  Redis: SISMEMBER
    def member?(value)
      redis.sismember(key, to_redis(value))
    end
    alias_method :include?, :member?
    
    # Delete the value from the set.  Redis: SREM
    def delete(value)
      redis.srem(key, to_redis(value))
    end
    
    # Delete if matches block
    def delete_if(&block)
      res = false
      redis.smembers(key).each do |m|
        if block.call(from_redis(m))
          res = redis.srem(key, m)
        end
      end
      res
    end
    
    # Iterate through each member of the set.  Redis::Objects mixes in Enumerable,
    # so you can also use familiar methods like +collect+, +detect+, and so forth.
    def each(&block)
      members.each(&block)
    end

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

    # The number of members in the set. Aliased as size. Redis: SCARD
    def length
      redis.scard(key)
    end
    alias_method :size, :length
    alias_method :count, :length

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
      sets.collect{|set| set.is_a?(Redis::Set) ? set.key : set}
    end
    
  end
end

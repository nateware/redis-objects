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

    attr_reader :key, :options

    # Works like add.  Can chain together: list << 'a' << 'b'
    def <<(value)
      add(value)
      self  # for << 'a' << 'b'
    end

    # Add the specified value to the set only if it does not exist already.
    # Redis: SADD
    def add(value)
      allow_expiration do
        redis.sadd(key, marshal(value)) if value.nil? || !Array(value).empty?
      end
    end

    # Remove and return a random member.  Redis: SPOP
    def pop
      unmarshal redis.spop(key)
    end

    # return a random member.  Redis: SRANDMEMBER
    def randmember(count = nil)
      unmarshal redis.srandmember(key, count)
    end

    # Adds the specified values to the set. Only works on redis > 2.4
    # Redis: SADD
    def merge(*values)
      allow_expiration do
        redis.sadd(key, values.flatten.map{|v| marshal(v)})
      end
    end

    # Return all members in the set.  Redis: SMEMBERS
    def members
      vals = redis.smembers(key)
      vals.nil? ? [] : vals.map{|v| unmarshal(v) }
    end
    alias_method :get, :members
    alias_method :value, :members

    # Returns true if the specified value is in the set.  Redis: SISMEMBER
    def member?(value)
      redis.sismember(key, marshal(value))
    end
    alias_method :include?, :member?

    # Delete the value from the set.  Redis: SREM
    def delete(value)
      redis.srem(key, marshal(value))
    end

    # Delete if matches block
    def delete_if(&block)
      res = false
      redis.smembers(key).each do |m|
        if block.call(unmarshal(m))
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
      redis.sinter(key, *keys_from_objects(sets)).map{|v| unmarshal(v)}
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
      redis.sunion(key, *keys_from_objects(sets)).map{|v| unmarshal(v)}
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
      redis.sdiff(key, *keys_from_objects(sets)).map{|v| unmarshal(v)}
    end
    alias_method :diff, :difference
    alias_method :^, :difference
    alias_method :-, :difference

    # Calculate the diff and store it in Redis as +name+. Returns the number
    # of elements in the stored union. Redis: SDIFFSTORE
    def diffstore(name, *sets)
      redis.sdiffstore(name, key, *keys_from_objects(sets))
    end

    # Moves value from one set to another. Destination can be a String
    # or Redis::Set.
    #
    #   set.move(value, "name_of_key_in_redis")
    #   set.move(value, set2)
    #
    # Returns true if moved successfully.
    #
    # Redis: SMOVE
    def move(value, destination)
      redis.smove(key, destination.is_a?(Redis::Set) ? destination.key : destination.to_s, value)
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

    def as_json(*)
      to_hash
    end

    private

    def keys_from_objects(sets)
      raise ArgumentError, "Must pass in one or more set names" if sets.empty?
      sets.collect{|set| set.is_a?(Redis::Set) ? set.key : set}
    end
  end
end

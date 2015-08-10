require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a sorted set.
  #
  class SortedSet < BaseObject
    # require 'enumerator'
    # include Enumerable
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands

    attr_reader :key, :options

    # How to add values using a sorted set.  The key is the member, eg,
    # "Peter", and the value is the score, eg, 163.  So:
    #    num_posts['Peter'] = 163
    def []=(member, score)
      add(member, score)
    end

    # Add a member and its corresponding value to Redis.  Note that the
    # arguments to this are flipped; the member comes first rather than
    # the score, since the member is the unique item (not the score).
    def add(member, score)
      allow_expiration do
        redis.zadd(key, score, marshal(member))
      end
    end

    # Add a list of members and their corresponding value (or a hash mapping
    # values to scores) to Redis. Note that the arguments to this are flipped;
    # the member comes first rather than the score, since the member is the unique
    # item (not the score).
    def merge(values)
      allow_expiration do
        vals = values.map{|v,s| [s, marshal(v)] }
        redis.zadd(key, vals)
      end
    end
    alias_method :add_all, :merge

    # Same functionality as Ruby arrays.  If a single number is given, return
    # just the element at that index using Redis: ZRANGE. Otherwise, return
    # a range of values using Redis: ZRANGE.
    def [](index, length=nil)
      if index.is_a? Range
        range(index.first, index.max)
      elsif length
        case length <=> 0
        when 1  then range(index, index + length - 1)
        when 0  then []
        when -1 then nil  # Ruby does this (a bit weird)
        end
      else
        result = score(index) || 0 # handles a nil score
      end
    end
    alias_method :slice, :[]

    # Return the score of the specified element of the sorted set at key. If the
    # specified element does not exist in the sorted set, or the key does not exist
    # at all, nil is returned. Redis: ZSCORE.
    def score(member)
      result = redis.zscore(key, marshal(member))

      result.to_f unless result.nil?
    end

    # Return the rank of the member in the sorted set, with scores ordered from
    # low to high. +revrank+ returns the rank with scores ordered from high to low.
    # When the given member does not exist in the sorted set, nil is returned.
    # The returned rank (or index) of the member is 0-based for both commands
    def rank(member)
      if n = redis.zrank(key, marshal(member))
        n.to_i
      else
        nil
      end
    end

    def revrank(member)
      if n = redis.zrevrank(key, marshal(member))
        n.to_i
      else
        nil
      end
    end

    # Return all members of the sorted set with their scores.  Extremely CPU-intensive.
    # Better to use a range instead.
    def members(options={})
      range(0, -1, options) || []
    end
    alias_method :value, :members

    # Return a range of values from +start_index+ to +end_index+.  Can also use
    # the familiar list[start,end] Ruby syntax. Redis: ZRANGE
    def range(start_index, end_index, options={})
      if options[:withscores] || options[:with_scores]
        redis.zrange(key, start_index, end_index, :with_scores => true).map{|v,s| [unmarshal(v), s] }
      else
        redis.zrange(key, start_index, end_index).map{|v| unmarshal(v) }
      end
    end

    # Return a range of values from +start_index+ to +end_index+ in reverse order. Redis: ZREVRANGE
    def revrange(start_index, end_index, options={})
      if options[:withscores] || options[:with_scores]
        redis.zrevrange(key, start_index, end_index, :with_scores => true).map{|v,s| [unmarshal(v), s] }
      else
        redis.zrevrange(key, start_index, end_index).map{|v| unmarshal(v) }
      end
    end

    # Return the all the elements in the sorted set at key with a score between min and max
    # (including elements with score equal to min or max).  Options:
    #     :count, :offset - passed to LIMIT
    #     :withscores     - if true, scores are returned as well
    # Redis: ZRANGEBYSCORE
    def rangebyscore(min, max, options={})
      args = {}
      args[:limit] = [options[:offset] || 0, options[:limit] || options[:count]] if
                options[:offset] || options[:limit] || options[:count]
      args[:with_scores] = true if options[:withscores] || options[:with_scores]

      redis.zrangebyscore(key, min, max, args).map{|v| unmarshal(v) }
    end

    # Returns all the elements in the sorted set at key with a score between max and min
    # (including elements with score equal to max or min). In contrary to the default ordering of sorted sets,
    # for this command the elements are considered to be ordered from high to low scores.
    # Options:
    #     :count, :offset - passed to LIMIT
    #     :withscores     - if true, scores are returned as well
    # Redis: ZREVRANGEBYSCORE
    def revrangebyscore(max, min, options={})
      args = {}
      args[:limit] = [options[:offset] || 0, options[:limit] || options[:count]] if
                options[:offset] || options[:limit] || options[:count]
      args[:with_scores] = true if options[:withscores] || options[:with_scores]

      redis.zrevrangebyscore(key, max, min, args).map{|v| unmarshal(v) }
    end

    # Remove all elements in the sorted set at key with rank between start and end. Start and end are
    # 0-based with rank 0 being the element with the lowest score. Both start and end can be negative
    # numbers, where they indicate offsets starting at the element with the highest rank. For example:
    # -1 is the element with the highest score, -2 the element with the second highest score and so forth.
    # Redis: ZREMRANGEBYRANK
    def remrangebyrank(min, max)
      redis.zremrangebyrank(key, min, max)
    end

    # Remove all the elements in the sorted set at key with a score between min and max (including
    # elements with score equal to min or max). Redis: ZREMRANGEBYSCORE
    def remrangebyscore(min, max)
      redis.zremrangebyscore(key, min, max)
    end

    # Delete the value from the set.  Redis: ZREM
    def delete(value)
      allow_expiration do
        redis.zrem(key, marshal(value))
      end
    end

    # Delete element if it matches block
    def delete_if(&block)
      raise ArgumentError, "Missing block to SortedSet#delete_if" unless block_given?
      res = false
      redis.zrange(key, 0, -1).each do |m|
        if block.call(unmarshal(m))
          res = redis.zrem(key, m)
        end
      end
      res
    end

    # Increment the rank of that member atomically and return the new value. This
    # method is aliased as incr() for brevity. Redis: ZINCRBY
    def increment(member, by=1)
      allow_expiration do
        zincrby(member, by)
      end
    end
    alias_method :incr, :increment
    alias_method :incrby, :increment

    # Convenience to calling increment() with a negative number.
    def decrement(member, by=1)
      allow_expiration do
        zincrby(member, -by)
      end
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
      redis.zinter(key, *keys_from_objects(sets)).map{|v| unmarshal(v) }
    end
    alias_method :intersect, :intersection
    alias_method :inter, :intersection
    alias_method :&, :intersection

    # Calculate the intersection and store it in Redis as +name+. Returns the number
    # of elements in the stored intersection. Redis: SUNIONSTORE
    def interstore(name, *sets)
      allow_expiration do
        opts = sets.last.is_a?(Hash) ? sets.pop : {}
        redis.zinterstore(key_from_object(name), keys_from_objects([self] + sets), opts)
      end
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
      redis.zunion(key, *keys_from_objects(sets)).map{|v| unmarshal(v) }
    end
    alias_method :|, :union
    alias_method :+, :union

    # Calculate the union and store it in Redis as +name+. Returns the number
    # of elements in the stored union. Redis: SUNIONSTORE
    def unionstore(name, *sets)
      allow_expiration do
        opts = sets.last.is_a?(Hash) ? sets.pop : {}
        redis.zunionstore(key_from_object(name), keys_from_objects([self] + sets), opts)
      end
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
      redis.zdiff(key, *keys_from_objects(sets)).map{|v| unmarshal(v) }
    end
    alias_method :diff, :difference
    alias_method :^, :difference
    alias_method :-, :difference

    # Calculate the diff and store it in Redis as +name+. Returns the number
    # of elements in the stored union. Redis: SDIFFSTORE
    def diffstore(name, *sets)
      redis.zdiffstore(name, key, *keys_from_objects(sets))
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

    # Return the value at the given index. Can also use familiar list[index] syntax.
    # Redis: ZRANGE
    def at(index)
      range(index, index).first
    end

    # Return the first element in the list. Redis: ZRANGE(0)
    def first
      at(0)
    end

    # Return the last element in the list. Redis: ZRANGE(-1)
    def last
      at(-1)
    end

    # The number of members in the set. Aliased as size. Redis: ZCARD
    def length
      redis.zcard(key)
    end
    alias_method :size, :length

    # The number of members within a range of scores. Redis: ZCOUNT
    def range_size(min, max)
      redis.zcount(key, min, max)
    end

    # Return a boolean indicating whether +value+ is a member.
    def member?(value)
      !redis.zscore(key, marshal(value)).nil?
    end

    private
    def key_from_object(set)
      set.is_a?(Redis::SortedSet) ? set.key : set
    end

    def keys_from_objects(sets)
      raise ArgumentError, "Must pass in one or more set names" if sets.empty?
      sets.collect{|set| set.is_a?(Redis::SortedSet) || set.is_a?(Redis::Set) ? set.key : set}
    end

    def zincrby(member, by)
      redis.zincrby(key, by, marshal(member)).to_i
    end
  end
end

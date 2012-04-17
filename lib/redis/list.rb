require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a Redis list.  Instances of Redis::List are designed to
  # behave as much like Ruby arrays as possible.
  #
  class List < BaseObject
    require 'enumerator'
    include Enumerable
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands
    require 'redis/helpers/serialize'
    include Redis::Helpers::Serialize

    attr_reader :key, :options, :redis

    # Works like push.  Can chain together: list << 'a' << 'b'
    def <<(value)
      push(value)
      self  # for << 'a' << 'b'
    end

    # Add a member to the end of the list. Redis: RPUSH
    def push(value)
      redis.rpush(key, to_redis(value))
      redis.ltrim(key, -options[:maxlength], -1) if options[:maxlength]
    end

    # Remove a member from the end of the list. Redis: RPOP
    def pop
      from_redis redis.rpop(key)
    end

    # Atomically pops a value from one list, pushes to another and returns the
    # value.  Destination can be a String or a Redis::List
    #
    #   list.rpoplpush(destination)
    #
    # Returns the popped/pushed value.
    #
    # Redis: RPOPLPUSH
    def rpoplpush(destination)
      from_redis redis.rpoplpush(key, destination.is_a?(Redis::List) ? destination.key : destination.to_s)
    end

    # Add a member to the start of the list. Redis: LPUSH
    def unshift(value)
      redis.lpush(key, to_redis(value))
      redis.ltrim(key, 0, options[:maxlength] - 1) if options[:maxlength]
    end

    # Remove a member from the start of the list. Redis: LPOP
    def shift
      from_redis redis.lpop(key)
    end

    # Return all values in the list. Redis: LRANGE(0,-1)
    def values
      v = from_redis range(0, -1)
      v.nil? ? [] : v
    end
    alias_method :get, :values

    # Same functionality as Ruby arrays.  If a single number is given, return
    # just the element at that index using Redis: LINDEX. Otherwise, return
    # a range of values using Redis: LRANGE.
    def [](index, length=nil)
      if index.is_a? Range
        last = index.exclude_end? ? (index.last - 1) : index.last
        range(index.first, last)
      elsif length
        case length <=> 0
        when 1  then range(index, index + length - 1)
        when 0  then []
        when -1 then nil  # Ruby does this (a bit weird)
        end
      else
        at(index)
      end
    end
    alias_method :slice, :[]

    # Delete the element(s) from the list that match name. If count is specified,
    # only the first-N (if positive) or last-N (if negative) will be removed.
    # Use .del to completely delete the entire key.
    # Redis: LREM
    def delete(name, count=0)
      redis.lrem(key, count, to_redis(name))  # weird api
    end

    # Iterate through each member of the set.  Redis::Objects mixes in Enumerable,
    # so you can also use familiar methods like +collect+, +detect+, and so forth.
    def each(&block)
      values.each(&block)
    end

    # Return a range of values from +start_index+ to +end_index+.  Can also use
    # the familiar list[start,end] Ruby syntax. Redis: LRANGE
    def range(start_index, end_index)
      from_redis redis.lrange(key, start_index, end_index)
    end

    # Return the value at the given index. Can also use familiar list[index] syntax.
    # Redis: LINDEX
    def at(index)
      from_redis redis.lindex(key, index)
    end

    # Return the first element in the list. Redis: LINDEX(0)
    def first
      at(0)
    end

    # Return the last element in the list. Redis: LINDEX(-1)
    def last
      at(-1)
    end

    # Return the length of the list. Aliased as size. Redis: LLEN
    def length
      redis.llen(key)
    end
    alias_method :size, :length
   
    # Returns true if there are no elements in the list. Redis: LLEN == 0
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

require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a Redis hash.
  #
  class HashKey < BaseObject
    require 'enumerator'
    include Enumerable
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands

    attr_reader :key, :options
    def initialize(key, *args)
      super
      @options[:marshal_keys] ||= {} 
    end

    # Redis: HSET
    def store(field, value)
      redis.with do |conn|
        conn.hset(key, field, marshal(value, options[:marshal_keys][field]))
      end
    end
    alias_method :[]=, :store

    # Redis: HGET
    def hget(field)
      redis.with do |conn|
        unmarshal conn.hget(key, field), options[:marshal_keys][field]
      end
    end
    alias_method :get, :hget
    alias_method :[],  :hget

    # Verify that a field exists. Redis: HEXISTS
    def has_key?(field)
      redis.with do |conn|
        conn.hexists(key, field)
      end
    end
    alias_method :include?, :has_key?
    alias_method :key?, :has_key?
    alias_method :member?, :has_key?

    # Delete field. Redis: HDEL
    def delete(field)
      redis.with do |conn|
        conn.hdel(key, field)
      end
    end

    # Fetch a key in a way similar to Ruby's Hash#fetch
    def fetch(field, *args, &block)
      value = hget(field)
      default = args[0]

      return value if value || (!default && !block_given?)

      block_given? ? block.call(field) : default
    end

    # Return all the keys of the hash. Redis: HKEYS
    def keys
      redis.with do |conn|
        conn.hkeys(key)
      end
    end

    # Return all the values of the hash. Redis: HVALS
    def values
      redis.with do |conn|
        conn.hvals(key).map{|v| unmarshal(v) }
      end
    end
    alias_method :vals, :values

    # Retrieve the entire hash.  Redis: HGETALL
    def all
      redis.with do |conn|
        h = conn.hgetall(key) || {}
        h.each{|k,v| h[k] = unmarshal(v, options[:marshal_keys][k]) }
        h
      end
    end
    alias_method :clone, :all

    # Enumerate through all fields. Redis: HGETALL
    def each(&block)
      all.each(&block)
    end

    # Enumerate through each keys. Redis: HKEYS
    def each_key(&block)
      keys.each(&block)
    end

    # Enumerate through all values. Redis: HVALS
    def each_value(&block)
      values.each(&block)
    end

    # Return the size of the dict. Redis: HLEN
    def size
      redis.with do |conn|
        conn.hlen(key)
      end
    end
    alias_method :length, :size
    alias_method :count, :size

    # Returns true if dict is empty
    def empty?
      true if size == 0
    end

    # Clears the dict of all keys/values. Redis: DEL
    def clear
      redis.with do |conn|
        conn.del(key)
      end
    end

    # Set keys in bulk, takes a hash of field/values {'field1' => 'val1'}. Redis: HMSET
    def bulk_set(*args)
      raise ArgumentError, "Argument to bulk_set must be hash of key/value pairs" unless args.last.is_a?(::Hash)
      redis.with do |conn|
        conn.hmset(key, *args.last.inject([]){ |arr,kv|
          arr + [kv[0], marshal(kv[1], options[:marshal_keys][kv[0]])]
        })
      end
    end
    alias_method :update, :bulk_set

    # Set keys in bulk if they do not exist. Takes a hash of field/values {'field1' => 'val1'}. Redis: HSETNX
    def fill(pairs={})
      raise ArgumentError, "Arugment to fill must be a hash of key/value pairs" unless pairs.is_a?(::Hash)
      redis.with do |conn|
        pairs.each do |field, value|
          conn.hsetnx(key, field, marshal(value, options[:marshal_keys][field]))
        end
      end
    end

    # Get keys in bulk, takes an array of fields as arguments. Redis: HMGET
    def bulk_get(*fields)
      hsh = {}
      redis.with do |conn|
        res = conn.hmget(key, *fields.flatten)
        fields.each do |k|
          hsh[k] = unmarshal(res.shift, options[:marshal_keys][k])
        end
        hsh
      end
    end

    # Get values in bulk, takes an array of keys as arguments.
    # Values are returned in a collection in the same order than their keys in *keys Redis: HMGET
    def bulk_values(*keys)
      redis.with do |conn|
        res = conn.hmget(key, *keys.flatten)
        keys.inject([]){|collection, k| collection << unmarshal(res.shift, options[:marshal_keys][k])}
      end
    end

    # Increment value by integer at field. Redis: HINCRBY
    def incrby(field, by=1)
      redis.with do |conn|
        ret = conn.hincrby(key, field, by)
        unless ret.is_a? Array
          ret.to_i
        else
          nil
        end
      end
    end
    alias_method :incr, :incrby

    # Decrement value by integer at field. Redis: HINCRBY
    def decrby(field, by=1)
      incrby(field, -by)
    end
    alias_method :decr, :decrby

    # Increment value by float at field. Redis: HINCRBYFLOAT
    def incrbyfloat(field, by=1.0)
      redis.with do |conn|
        ret = conn.hincrbyfloat(key, field, by)
        unless ret.is_a? Array
          ret.to_f
        else
          nil
        end
      end
    end

    # Decrement value by float at field. Redis: HINCRBYFLOAT
    def decrbyfloat(field, by=1.0)
      incrbyfloat(field, -by)
    end

    expiration_filter :[]=, :store, :bulk_set, :fill,
                      :incrby, :incr, :incrbyfloat,
                      :decrby, :decr, :decrbyfloat
  end
end


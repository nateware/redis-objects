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
      allow_expiration do
        redis.hset(key, field, marshal(value, options[:marshal_keys][field]))
      end
    end
    alias_method :[]=, :store

    # Redis: HGET
    def hget(field)
      unmarshal redis.hget(key, field), options[:marshal_keys][field]
    end
    alias_method :get, :hget
    alias_method :[],  :hget

    # Verify that a field exists. Redis: HEXISTS
    def has_key?(field)
      redis.hexists(key, field)
    end
    alias_method :include?, :has_key?
    alias_method :key?, :has_key?
    alias_method :member?, :has_key?

    # Delete fields. Redis: HDEL
    def delete(*field)
      redis.hdel(key, field)
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
      redis.hkeys(key)
    end

    # Return all the values of the hash. Redis: HVALS
    def values
      redis.hvals(key).map{|v| unmarshal(v) }
    end
    alias_method :vals, :values

    # Retrieve the entire hash.  Redis: HGETALL
    def all
      h = redis.hgetall(key) || {}
      h.each{|k,v| h[k] = unmarshal(v, options[:marshal_keys][k]) }
      h
    end
    alias_method :clone, :all
    alias_method :value, :all

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
    def bulk_set(*args)
      raise ArgumentError, "Argument to bulk_set must be hash of key/value pairs" unless args.last.is_a?(::Hash)
      allow_expiration do
        redis.hmset(key, *args.last.inject([]){ |arr,kv|
          arr + [kv[0], marshal(kv[1], options[:marshal_keys][kv[0]])]
        })
      end
    end
    alias_method :update, :bulk_set

    # Set keys in bulk if they do not exist. Takes a hash of field/values {'field1' => 'val1'}. Redis: HSETNX
    def fill(pairs={})
      raise ArgumentError, "Argument to fill must be a hash of key/value pairs" unless pairs.is_a?(::Hash)
      allow_expiration do
        pairs.each do |field, value|
          redis.hsetnx(key, field, marshal(value, options[:marshal_keys][field]))
        end
      end
    end

    # Get keys in bulk, takes an array of fields as arguments. Redis: HMGET
    def bulk_get(*fields)
      hsh = {}
      get_fields = *fields.flatten
      get_fields << nil if get_fields.empty?
      res = redis.hmget(key, get_fields)
      fields.each do |k|
        hsh[k] = unmarshal(res.shift, options[:marshal_keys][k])
      end
      hsh
    end

    # Get values in bulk, takes an array of keys as arguments.
    # Values are returned in a collection in the same order than their keys in *keys Redis: HMGET
    def bulk_values(*keys)
      get_keys = *keys.flatten
      get_keys << nil if get_keys.empty?
      res = redis.hmget(key, get_keys)
      keys.inject([]){|collection, k| collection << unmarshal(res.shift, options[:marshal_keys][k])}
    end

    # Increment value by integer at field. Redis: HINCRBY
    def incrby(field, by=1)
      allow_expiration do
        ret = redis.hincrby(key, field, by)
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
      allow_expiration do
        ret = redis.hincrbyfloat(key, field, by)
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

    def as_json(*)
      to_hash
    end
  end
end

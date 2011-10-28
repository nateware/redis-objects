require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a simple value.  You can use standard Ruby operations on it.
  #
  class Value < BaseObject
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands
    require 'redis/helpers/serialize'
    include Redis::Helpers::Serialize

    attr_reader :key, :options, :redis
    def initialize(key, *args)
      super(key, *args)
      @redis.setnx(key, @options[:default]) if @options[:default]
    end

    def value=(val)
      if val.nil?
        delete
      else
        redis.set key, to_redis(val)
      end
    end
    alias_method :set, :value=

    def value
      from_redis redis.get(key)
    end
    alias_method :get, :value

    def inspect
      "#<Redis::Value #{value.inspect}>"
    end

    def ==(other); value == other end
    def nil?; value.nil? end
    def as_json(*args); value.as_json *args end
    def to_json(*args); value.to_json *args end

    def method_missing(*args)
      self.value.send *args
    end
  end
end

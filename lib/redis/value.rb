require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a simple value.  You can use standard Ruby operations on it.
  #
  class Value < BaseObject
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands

    attr_reader :key, :options

    def value=(val)
      allow_expiration do
        if val.nil?
          delete
        else
          redis.set key, marshal(val)
        end
      end
    end
    alias_method :set, :value=

    def value
      value = unmarshal(redis.get(key))
      if value.nil? && !@options[:default].nil?
        @options[:default]
      else
        value
      end
    end
    alias_method :get, :value

    def inspect
      "#<Redis::Value #{value.inspect}>"
    end

    def ==(other); value == other end
    def nil?; value.nil? end

    def method_missing(*args)
      self.value.send *args
    end
  end
end

require File.dirname(__FILE__) + '/base_object'
require 'zlib'

class Redis
  #
  # Class representing a simple value.  You can use standard Ruby operations on it.
  #
  class Value < BaseObject
    def value=(val)
      return delete if val.nil?

      allow_expiration { redis.set key, marshal(val) }
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

    def marshal(value, *args)
      if !value.nil? && options[:compress]
        compress(super)
      else
        super
      end
    end

    def unmarshal(value, *args)
      if !value.nil? && options[:compress]
        super(decompress(value), *args)
      else
        super
      end
    end

    def decompress(value)
      Zlib::Inflate.inflate(value)
    end

    def compress(value)
      Zlib::Deflate.deflate(value)
    end

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

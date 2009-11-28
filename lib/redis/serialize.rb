class Redis
  module Serialize
    include Marshal

    def to_redis(value)
      case value
      when String, Fixnum, Bignum, Float
        value
      else
        dump(value)
      end
    end
    
    def from_redis(value)
      case value
      when Array
        value.collect{|v| from_redis(v)}
      else
        restore(value) rescue value
      end
    end
  end
end
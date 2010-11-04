class Redis
  module Helpers
    module Serialize
      include Marshal

      def to_redis(value)
        return value unless options[:marshal]
        case value
        when String, Fixnum, Bignum, Float
          value
        else
          dump(value)
        end
      end
    
      def from_redis(value)
        return value unless options[:marshal]
        case value
        when Array
          value.collect{|v| from_redis(v)}
        when Hash
          value.inject({}) { |h, (k, v)| h[k] = from_redis(v); h }
        else
          restore(value) rescue value
        end
      end
    end
  end
end
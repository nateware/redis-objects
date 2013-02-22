class Redis
  module Helpers
    module Serialize
      include Marshal

      def to_redis(value, marshal=false)
        return value unless options[:marshal] || marshal
        case value
        when String, Fixnum, Bignum, Float
          value
        else
          dump(value)
        end
      end
 
      def from_redis(value, marshal=false)
        # This was removed because we can't reliably determine
        # if a person said @value = "123.4" maybe for space/etc.
        #begin
        #  case value
        #  when /^\d+$/
        #    return Integer(value)
        #  when /^(?:\d+\d.\d*|\d*\.\d+)$/
        #    return Float(value)
        #  end
        #rescue
        #  # continue below
        #end
        return value unless options[:marshal] || marshal
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

module RedisObjects
  module Serializers

    class RMarshal
      def to_redis(value, opts={})
        case value
        when String, Fixnum, Bignum, Float
          value
        else
          Marshal.dump(value)
        end
      end

      def from_redis(value, opts={})
        Marshal.restore value rescue value
      end
    end

    class JSON
      DEFAULT_OPTS = {:symbolize_keys => true}

      def to_redis(value, opts={})
        case value
        when String, Fixnum, Bignum, Float
          value
        else
          Yajl::Encoder.encode value
        end
      end
      def from_redis(value, opts={})
        opts = DEFAULT_OPTS.merge opts

        Yajl::Parser.parse value, :symbolize_keys => opts[:symbolize_keys]
      end
    end
  end
end

Redis::Helpers::Serialize.register :marshal, RedisObjects::Serializers::RMarshal.new
Redis::Helpers::Serialize.register :json, RedisObjects::Serializers::JSON.new
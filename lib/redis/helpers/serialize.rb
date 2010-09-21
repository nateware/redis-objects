class Redis
  module Helpers
    module Serialize
      def to_redis(value)
        return value if options[:raw]
        Yajl::Encoder.encode(value)
      end

      def from_redis(value)
        return value if options[:raw]
        Yajl::Parser.parse(value, :symbolize_keys => options[:symbolize_keys])
      end

      def from_redis_list(value)
        return value if options[:raw]
        value.collect{|v| from_redis(v)}
      end
    end
  end
end
class Redis
  module Helpers
    module Serialize
      def self.register(name_sym, obj)
        @@serializers ||= {}
        @@serializers[name_sym] = obj
      end

      def serializer
        @serializer ||= @@serializers[options[:serialize]]
      end

      def send(value)
        serializer.send :to_redis, value, options
      end

      def retrieve(value)
        serializer.send :from_redis, value, options
      end

      def to_redis(value)
        # for backwards compatibility
        options[:serialize] = :marshal if options[:marshal]

        return value unless options[:serialize]

        send value
      end

      def from_redis(value)
        return value unless value && options[:serialize]

        case value
        when Array
          value.collect{|v| retrieve v }
        when Hash
          value.inject({}) { |h, (k, v)| h[k] = retrieve v; h }
        else
          retrieve value
        end
      end
    end
  end
end

require 'redis/helpers/serializers'
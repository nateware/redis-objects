class Redis
  # Defines base functionality for all redis-objects.
  class BaseObject
    def initialize(key, *args)
      @key     = key.is_a?(Array) ? key.flatten.join(':') : key
      @options = args.last.is_a?(Hash) ? args.pop : {}
      @myredis = Objects::ConnectionPoolProxy.proxy_if_needed(args.first)
    end

    # Dynamically query the handle to enable resetting midstream
    def redis
      @myredis || ::Redis::Objects.redis
    end

    alias :inspect :to_s  # Ruby 1.9.2

    def set_expiration
      if overwrite_ttl? || redis.ttl(@key) < 0
        if !@options[:expiration].nil?
          redis.expire(@key, @options[:expiration])
        elsif !@options[:expireat].nil?
          redis.expireat(@key, @options[:expireat].to_i)
        end
      end
    end

    def allow_expiration(&block)
      block.call.tap { set_expiration }
    end

    private
    def overwrite_ttl?
      @options[:overwrite_ttl].present?
    end
  end
end

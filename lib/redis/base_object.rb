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
      if !@options[:expiration].nil?
        redis.expire(@key, @options[:expiration]) if redis.ttl(@key) < 0
      elsif !@options[:expireat].nil?
        redis.expireat(@key, @options[:expireat].to_i) if redis.ttl(@key) < 0
      end
    end

    def allow_expiration(&block)
      result = block.call
      set_expiration
      result
    end

    def to_json(*args)
      to_hash.to_json(*args)
    rescue NoMethodError => e
      raise e.class, "The current runtime does not provide a `to_json` implementation. Require 'json' or another JSON library and try again."
    end

    def as_json(*)
      to_hash
    end

    def to_hash
      { "key" => @key, "options" => @options, "value" => value }
    end
  end
end

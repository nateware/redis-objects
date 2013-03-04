class Redis
  # Defines base functionality for all redis-objects.
  class BaseObject
    def initialize(key, *args)
      @key     = key.is_a?(Array) ? key.flatten.join(':') : key
      @options = args.last.is_a?(Hash) ? args.pop : {}
      @myredis = args.first 
    end

    # Dynamically query the handle to enable resetting midstream
    def redis
      @myredis || ::Redis::Objects.redis
    end

    def setter_methods
      []
    end

    alias :inspect :to_s  # Ruby 1.9.2
  end
end

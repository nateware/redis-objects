class Redis
  # Defines base functionality for all redis-objects.
  class BaseObject
    def initialize(key, *args)
      @key     = key.is_a?(Array) ? key.flatten.join(':') : key
      @options = args.last.is_a?(::Hash) ? args.pop : {}  # ::Hash because of Redis::Hash
      @redis   = args.first || $redis
    end
  end
end

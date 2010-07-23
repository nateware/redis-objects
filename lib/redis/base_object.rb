class Redis
  # Defines base functionality for all redis-objects.
  class BaseObject
    def initialize(key, *args)
      @key = key
      @options = args.last.is_a?(Hash) ? args.pop : {}
      @redis = args.first || $redis
    end
  end
end

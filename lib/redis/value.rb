class Redis
  #
  # Class representing a simple value.  You can use standard Ruby operations on it.
  #
  class Value
    attr_reader :key, :options, :redis
    def initialize(key, options={})
      @key = key
      @options = options
      @redis   = options[:redis] || $redis || Redis::Objects.redis
      @redis.setnx(key, @options[:default]) if @options[:default]
    end

    def value
      @value ||= get
    end

    def value=(val)
      redis.set(key, val)
      @value = val
    end
    
    def get
      @value = redis.get(key)
    end
    
    def delete
      redis.del(key)
      @value = nil
    end
    alias_method :del, :delete

    def to_s;  value.to_s; end
    alias_method :to_str, :to_s

    def ==(x); value == x; end
    def nil?;  value.nil?; end
  end
end
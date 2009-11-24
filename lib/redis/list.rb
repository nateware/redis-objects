class Redis
  #
  # Class representing a Redis list.  Instances of Redis::List are designed to 
  # behave as much like Ruby arrays as possible.
  #
  class List
    attr_reader :key, :options, :redis, :values
    def initialize(key, options={})
      @key = key
      @options = options
      @redis   = options[:redis] || $redis || Redis::Objects.redis
      @options[:start] ||= 0
      @options[:type]  ||= @options[:start] == 0 ? :increment : :decrement
      @redis.setnx(key, @options[:start]) unless @options[:start] == 0 || @options[:init] === false
    end
    
    def <<(value)
      push(value)
    end
    
    def push(value)
      @redis.rpush key, value
    end

    def unshift(value)
      @values << value
    end
  end
end
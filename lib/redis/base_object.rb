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

    alias :inspect :to_s  # Ruby 1.9.2

    def set_expiration
      redis.with do |conn|
        if !@options[:expiration].nil?
          conn.expire(@key, @options[:expiration]) if conn.ttl(@key) < 0
        elsif !@options[:expireat].nil?
          conn.expireat(@key, @options[:expireat].to_i) if conn.ttl(@key) < 0
        end
      end
    end

    class << self
      def expiration_filter(*names)
        names.each do |name|
          # http://blog.jayfields.com/2006/12/ruby-alias-method-alternative.html
          bind_method = instance_method(name)

          define_method(name) do |*args, &block|
            result = bind_method.bind(self).call(*args, &block)
            set_expiration
            result
          end
        end
      end
    end
  end
end

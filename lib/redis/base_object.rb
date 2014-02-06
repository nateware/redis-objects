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
      if !@options[:expiration].nil?
        redis.expire(@key, @options[:expiration]) if redis.ttl(@key) < 0
      elsif !@options[:expireat].nil?
        redis.expireat(@key, @options[:expireat].to_i) if redis.ttl(@key) < 0
      end
    end

    class << self
      def expiration_filter(*names)
        names.each do |name|
          if ['=', '?', '!'].include? name.to_s[-1]
            with_name = "#{name[0..-2]}_with_expiration#{name[-1]}".to_sym
            without_name = "#{name[0..-2]}_without_expiration#{name[-1]}".to_sym
          else
            with_name = "#{name}_with_expiration".to_sym
            without_name = "#{name}_without_expiration".to_sym
          end

          alias_method without_name, name

          define_method(with_name) do |*args|
            result = send(without_name, *args)
            set_expiration
            result
          end

          alias_method name, with_name
        end
      end
    end
  end
end

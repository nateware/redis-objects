require 'redis/helpers/core_commands'

class Redis
  # Defines base functionality for all redis-objects.
  class BaseObject
    include Redis::Helpers::CoreCommands

    attr_reader :key, :options

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
        redis.expire(@key, @options[:expiration])
      elsif !@options[:expireat].nil?
        expireat = @options[:expireat]
        at = expireat.respond_to?(:call) ? expireat.call.to_i : expireat.to_i
        redis.expireat(@key, at)
      end
    end

    def allow_expiration
      expiration_set = false
      result =
        redis.multi do
          yield
          expiration_set = set_expiration
        end
      # Nested calls to multi/pipelined return `nil`,
      # return value should be handled by outer call to multi/pipelined.
      return if result.nil?

      result.pop if expiration_set
      result.size == 1 ? result.first : result
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

    # Math ops - delegate to value method
    %w(== < > <= >=).each do |m|
      class_eval <<-EndOverload
        def #{m}(what)
          value #{m} what
        end
      EndOverload
    end
  end
end

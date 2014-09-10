require 'connection_pool'
require 'redis'
require 'uri'

# This code was inspired by @mperham sidekiq redis_connection class
# https://github.com/mperham/sidekiq/blob/27fc88504b15ea5b57929845c7118de66c3120ea/lib/sidekiq/redis_connection.rb

module RedisObjects
  class RedisConnection
    class << self

      def create(options={})
        url = options[:url]
        size = (options[:size] || 1) + 2
        pool_timeout = (options[:pool_timeout] || 1)

        log_info(options)

        ConnectionPool.new(:timeout => pool_timeout, :size => size) do
          build_client(options)
        end
      end

      private

      def build_client(options)
        namespace = options[:namespace]

        client = Redis.new client_opts(options)
        if namespace
          require 'redis/namespace'
          Redis::Namespace.new(namespace, :redis => client)
        else
          client
        end
      end

      def client_opts(options)
        opts = options.dup
        if opts[:namespace]
          opts.delete(:namespace)
        end

        if opts[:network_timeout]
          opts[:timeout] = opts[:network_timeout]
          opts.delete(:network_timeout)
        end

        opts
      end

      def log_info(options)
        # Don't log Redis AUTH password
        redacted = "REDACTED"
        scrubbed_options = options.dup
        if scrubbed_options[:url] && (uri = URI.parse(scrubbed_options[:url])) && uri.password
          uri.password = redacted
          scrubbed_options[:url] = uri.to_s
        end
        if scrubbed_options[:password]
          scrubbed_options[:password] = redacted
        end
        Logger.logger.info("Connecting redis-object with redis options #{scrubbed_options}")
      end
    end
  end
end
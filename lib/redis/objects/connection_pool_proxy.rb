class Redis
  module Objects
    class ConnectionPoolProxy
      def initialize(pool)
        raise ArgumentError "Should only proxy ConnectionPool!" unless self.class.should_proxy?(pool)
        @pool = pool
      end

      def method_missing(name, *args, &block)
        @pool.with { |x| x.send(name, *args, &block) }
      end

      def respond_to_missing?(name, include_all = false)
        @pool.with { |x| x.respond_to?(name, include_all) }
      end

      def self.should_proxy?(conn)
        defined?(::ConnectionPool) && conn.is_a?(::ConnectionPool)
      end

      def self.proxy_if_needed(conn)
        if should_proxy?(conn)
          ConnectionPoolProxy.new(conn)
        else
          conn
        end
      end
    end
  end
end

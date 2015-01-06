class Redis
  module Helpers
    # These are core commands that all types share (rename, etc)
    module CoreCommands
      def exists?
        redis.with do |conn|
          conn.exists key
        end
      end
      
      def delete
        redis.with do |conn|
          conn.del key
        end
      end
      alias_method :del, :delete
      alias_method :clear, :delete
      
      def type
        redis.with do |conn|
          conn.type key
        end
      end

      def rename(name, setkey=true)
        redis.with do |conn|
          dest = name.is_a?(self.class) ? name.key : name
          ret  = conn.rename key, dest
          @key = dest if ret && setkey
          ret
        end
      end

      def renamenx(name, setkey=true)
        redis.with do |conn|
          dest = name.is_a?(self.class) ? name.key : name
          ret  = conn.renamenx key, dest
          @key = dest if ret && setkey
          ret
        end
      end
    
      def expire(seconds)
        redis.with do |conn|
          conn.expire key, seconds
        end
      end

      def expireat(unixtime)
        redis.with do |conn|
          conn.expireat key, unixtime
        end
      end

      def persist
        redis.with do |conn|
          conn.persist key
        end
      end

      def ttl
        redis.with do |conn|
          conn.ttl(@key)
        end
      end

      def move(dbindex)
        redis.with do |conn|
          conn.move key, dbindex
        end
      end

      def sort(options={})
        redis.with do |conn|
          options[:order] = "asc alpha" if options.keys.count == 0  # compat with Ruby
          val = conn.sort(key, options)
          val.is_a?(Array) ? val.map{|v| unmarshal(v)} : val
        end
      end

      def marshal(value, domarshal=false)
        if options[:marshal] || domarshal
          Marshal.dump(value)
        else
          value
        end
      end
 
      def unmarshal(value, domarshal=false)
        if value.nil?
          nil
        elsif options[:marshal] || domarshal
          if value.is_a?(Array)
            value.map{|v| unmarshal(v, domarshal)}
          elsif !value.is_a?(String)
            value
          else
            Marshal.load(value) 
          end
        else
          value
        end
      end
    end
  end
end

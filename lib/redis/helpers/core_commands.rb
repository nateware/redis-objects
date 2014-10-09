class Redis
  module Helpers
    # These are core commands that all types share (rename, etc)
    module CoreCommands
      def exists?
        redis.exists key
      end
      
      def delete
        redis.del key
      end
      alias_method :del, :delete
      alias_method :clear, :delete
      
      def type
        redis.type key
      end

      def rename(name, setkey=true)
        dest = name.is_a?(self.class) ? name.key : name
        ret  = redis.rename key, dest
        @key = dest if ret && setkey
        ret
      end

      def renamenx(name, setkey=true)
        dest = name.is_a?(self.class) ? name.key : name
        ret  = redis.renamenx key, dest
        @key = dest if ret && setkey
        ret
      end
    
      def expire(seconds)
        redis.expire key, seconds
      end

      def expireat(unixtime)
        redis.expireat key, unixtime
      end

      def persist
        redis.persist key
      end

      def ttl
        redis.ttl(@key)
      end

      def move(dbindex)
        redis.move key, dbindex
      end

      def sort(options={})
        options[:order] = "asc alpha" if options.keys.count == 0  # compat with Ruby
        val = redis.sort(key, options)
        val.is_a?(Array) ? val.map{|v| unmarshal(v)} : val
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

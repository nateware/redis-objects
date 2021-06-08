class Redis
  module Helpers
    # These are core commands that all types share (rename, etc)
    module CoreCommands
      def exists?
        redis.exists? key
      end

      # Delete key. Redis: DEL
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

      def serializer
        options[:serializer] || Marshal
      end

      def marshal(value, domarshal=false)
        if options[:marshal] || domarshal
          dump_args = options[:marshal_dump_args] || []
          serializer.dump(value, *(dump_args.is_a?(Array) ? dump_args : [dump_args]))
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
            load_args = options[:marshal_load_args] || []
            serializer.load(value, *(load_args.is_a?(Array) ? load_args : [load_args]))
          end
        else
          value
        end
      end
    end
  end
end

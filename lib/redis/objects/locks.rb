# This is the class loader, for use as "include Redis::Objects::Locks"
# For the object itself, see "Redis::Lock"
require 'redis/lock'
class Redis
  module Objects
    class UndefinedLock < StandardError; end #:nodoc:
    module Locks
      def self.included(klass)
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      # Class methods that appear in your class when you include Redis::Objects.
      module ClassMethods
        # Define a new lock.  It will function like a model attribute,
        # so it can be used alongside ActiveRecord/DataMapper, etc.
        def lock(name, options={})
          options[:timeout] ||= 5  # seconds
          lock_name = "#{name}_lock"
          redis_objects[lock_name.to_sym] = options.merge(:type => :lock)

          mod = Module.new do
            define_method(lock_name) do |&block|
              instance_variable_get("@#{lock_name}") or
                instance_variable_set("@#{lock_name}",
                  Redis::Lock.new(
                    redis_field_key(lock_name), redis_field_redis(lock_name), redis_objects[lock_name.to_sym]
                  )
                )
            end
          end

          if options[:global]
            extend mod

            # dispatch to class methods
            define_method(lock_name) do |&block|
              self.class.public_send(lock_name, &block)
            end
          else
            include mod
          end
        end

        # Obtain a lock, and execute the block synchronously.  Any other code
        # (on any server) will spin waiting for the lock up to the :timeout
        # that was specified when the lock was defined.
        def obtain_lock(name, id, &block)
          verify_lock_defined!(name)
          raise ArgumentError, "Missing block to #{self.name}.obtain_lock" unless block_given?
          lock_name = "#{name}_lock"
          Redis::Lock.new(redis_field_key(lock_name, id), redis_field_redis(lock_name), redis_objects[lock_name.to_sym]).lock(&block)
        end

        # Clear the lock.  Use with care - usually only in an Admin page to clear
        # stale locks (a stale lock should only happen if a server crashes.)
        def clear_lock(name, id)
          verify_lock_defined!(name)
          redis.del(redis_field_key("#{name}_lock", id))
        end

        private

        def verify_lock_defined!(name)
          unless redis_objects.has_key?("#{name}_lock".to_sym)
            raise Redis::Objects::UndefinedLock, "Undefined lock :#{name} for class #{self.name}"
          end
        end
      end
    end
  end
end

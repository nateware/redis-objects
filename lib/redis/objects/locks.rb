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
          @redis_objects[lock_name.to_sym] = options.merge(:type => :lock)
          klass_name = self.name
          if options[:global]
            instance_eval <<-EndMethods
              def #{lock_name}(&block)
                @#{lock_name} ||= Redis::Lock.new(field_key(:#{lock_name}), #{klass_name}.redis, #{klass_name}.redis_objects[:#{lock_name}])
              end
            EndMethods
            class_eval <<-EndMethods
              def #{lock_name}(&block)
                self.class.#{lock_name}(block)
              end
            EndMethods
          else
            class_eval <<-EndMethods
              def #{lock_name}(&block)
                @#{lock_name} ||= Redis::Lock.new(field_key(:#{lock_name}), #{klass_name}.redis, #{klass_name}.redis_objects[:#{lock_name}])
              end
            EndMethods
          end
        end

        # Obtain a lock, and execute the block synchronously.  Any other code
        # (on any server) will spin waiting for the lock up to the :timeout
        # that was specified when the lock was defined.
        def obtain_lock(name, id, &block)
          verify_lock_defined!(name)
          raise ArgumentError, "Missing block to #{self.name}.obtain_lock" unless block_given?
          lock_name = "#{name}_lock"
          Redis::Lock.new(field_key(lock_name, id), redis, @redis_objects[lock_name.to_sym]).lock(&block)
        end

        # Clear the lock.  Use with care - usually only in an Admin page to clear
        # stale locks (a stale lock should only happen if a server crashes.)
        def clear_lock(name, id)
          verify_lock_defined!(name)
          redis.del(field_key("#{name}_lock", id))
        end

        private
        
        def verify_lock_defined!(name)
          unless @redis_objects.has_key?("#{name}_lock".to_sym)
            raise Redis::Objects::UndefinedLock, "Undefined lock :#{name} for class #{self.name}"
          end
        end
      end
    end
  end
end

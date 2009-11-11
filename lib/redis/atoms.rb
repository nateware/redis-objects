# Redis::Atoms - Use Redis to support atomic operations in your app.
# See README.rdoc for usage and approach.
require 'redis'
class Redis
  module Atoms
    class UndefinedCounter < StandardError; end
    class LockTimeout < StandardError; end

    class << self
      def redis=(conn) @redis = conn end
      def redis
        @redis ||= $redis || raise("Redis::Atoms.redis not set")
      end

      def included(klass)
        klass.instance_variable_set('@redis', @redis)
        klass.instance_variable_set('@counters', {})
        klass.instance_variable_set('@locks', {})
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end
    end

    module ClassMethods
      attr_accessor :redis
      
      # Set the Redis prefix to use. Defaults to model_name
      def prefix=(prefix) @prefix = prefix end
      def prefix #:nodoc:
        @prefix ||= self.name.to_s.
          sub(%r{(.*::)}, '').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          downcase
      end
      
      def field_key(name, id) #:nodoc:
        "#{prefix}:#{id}:#{name}"
      end

      # Define a new counter.  It will function like a model attribute,
      # so it can be used alongside ActiveRecord/DataMapper, etc.
      def counter(name, options={})
        options[:start] ||= 0
        @counters[name] = options
        class_eval <<-EndMethods
          def #{name}_counter_name
            # lazily initialize counter to save trip
            @#{name}_counter_name ||= begin
              name = field_key(:#{name})
              redis.setnx(name, #{options[:start]})
              name
            end
          end
          def #{name}
            redis.get(#{name}_counter_name).to_i
          end
          def increment_#{name}(by=1)
            redis.incr(#{name}_counter_name, by).to_i
          end
          def decrement_#{name}(by=1)
            redis.decr(#{name}_counter_name, by).to_i
          end
          def reset_#{name}(to=#{options[:start]})
            redis.set(#{name}_counter_name, to)
          end
          def clear_#{name}  # dangerous/not needed?
            ret = redis.del(#{name}_counter_name)
            @#{name}_counter_name = nil  # triggers setnx
            ret
          end
          def if_#{name}_left(test=0, &block)
            raise ArgumentError, "Missing block to if_#{name}" unless block_given?
            val = decrement_#{name}
            if val >= test  # >= because of decrement
              begin
                yield
              rescue
                increment_#{name}
                raise
              end
            else
              increment_#{name}
            end
          end
        EndMethods
      end

      # Get the current value of the counter.
      def get_counter(name, id)
        verify_counter_defined!(name)
        redis.setnx(field_key(name, id), @counters[name][:start])  # have to do each time from the class
        redis.get(field_key(name, id)).to_i
      end

      # Increment a counter with the specified name and id.  It is slightly
      # more efficient to use the model instance method if possible.
      def increment_counter(name, id, by=1)
        verify_counter_defined!(name)
        redis.setnx(field_key(name, id), @counters[name][:start])  # have to do each time from the class
        redis.incr(field_key(name, id), by).to_i
      end

      # Decrement a counter with the specified name and id.  It is slightly
      # more efficient to use the model instance method if possible.
      def decrement_counter(name, id, by=1)
        verify_counter_defined!(name)
        redis.setnx(field_key(name, id), @counters[name][:start])  # have to do each time from the class
        redis.decr(field_key(name, id), by).to_i
      end

      # Reset a counter
      def reset_counter(name, id, to=nil)
        verify_counter_defined!(name)
        to = @counters[name][:start] if to.nil?
        redis.set(field_key(name, id), to)
      end

      # Only execute the block if a counter is above a certain threshold.
      def if_counter_left(name, id, test=0)
        verify_counter_defined!(name)
        redis.setnx(field_key(name, id), @counters[name][:start])  # have to do each time from the class
        to = @counters[name][:start] if to.nil?
        redis.set(field_key(name, id), to)
      end

      def verify_counter_defined!(name)
        raise UndefinedCounter, "Undefined counter :#{name} for class #{self.name}" unless @counters.has_key?(name)
      end

      # Define a new lock.  It will function like a model attribute,
      # so it can be used alongside ActiveRecord/DataMapper, etc.
      def lock(name, options={})
        options[:timeout] ||= 5  # seconds
        @locks[name] = options
        class_eval <<-EndMethods
          def #{name}_lock_name
            @#{name}_lock_name ||= field_key(:#{name}_lock)
          end
          def lock_#{name}(&block)
            raise ArgumentError, "Missing block to lock_#{name}" unless block_given?
            self.class.obtain_lock(:#{name}, id, &block)
          end
          def clear_#{name}_lock
            redis.del(#{name}_lock_name)
          end
        EndMethods
      end

      # Obtain a lock
      def obtain_lock(name, id, &block)
        raise ArgumentError, "Missing block to #{self.name}.obtain_lock" unless block_given?
        verify_lock_defined!(name)
        lock_name = field_key("#{name}_lock", id)
        start = Time.now
        gotit = false
        while Time.now - start < @locks[name][:timeout]
          gotit = redis.setnx(lock_name, 1)
          break if gotit
          sleep 0.1
        end
        raise LockTimeout, "Timeout on lock :#{name} (#{@locks[name][:timeout]} sec) for #{self.name} with ID=#{id}" unless gotit
        begin
          yield
        ensure
          redis.del(lock_name)
        end
      end

      def clear_lock(name, id)
        verify_counter_defined!(name)
        lock_name = field_key("#{name}_lock", id)
        redis.del(lock_name)
      end

      def verify_lock_defined!(name)
        raise UndefinedCounter, "Undefined lock :#{name} for class #{self.name}" unless @locks.has_key?(name)
      end
    end

    module InstanceMethods
      def redis() self.class.redis end
      def field_key(name) #:nodoc:
        self.class.field_key(name, id)
      end

      # Increment a counter.
      # It is more efficient to use increment_[counter_name] directly.
      def increment(name, by=1)
        send("increment_#{name}".to_sym, by)
      end

      # Decrement a counter.
      # It is more efficient to use increment_[counter_name] directly.
      def decrement(name, by=1)
        send("decrement_#{name}".to_sym, by)
      end
    end
  end
end

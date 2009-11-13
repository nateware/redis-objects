# Redis::Atoms - Use Redis to support atomic operations in your app.
# See README.rdoc for usage and approach.
require 'redis'
require 'redis/atoms/counter'
require 'redis/atoms/lock'
class Redis
  module Atoms
    class UndefinedAtom < StandardError; end

    class << self
      def redis=(conn) @redis = conn end
      def redis
        @redis ||= $redis || raise("Redis::Atoms.redis not set to a valid Redis connection")
      end

      def included(klass)
        klass.instance_variable_set('@redis', @redis)
        klass.instance_variable_set('@counters', {})
        klass.instance_variable_set('@locks', {})
        klass.instance_variable_set('@initialized_counters', {})
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end
    end

    # These class methods are added to the class you include Redis::Atoms in.
    module ClassMethods
      attr_accessor :redis
      attr_reader :counters, :locks, :initialized_counters

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

      # Define a new counter.  It will function like a regular instance
      # method, so it can be used alongside ActiveRecord, DataMapper, etc.
      def counter(name, options={})
        options[:start] ||= 0
        options[:type]  ||= options[:start] == 0 ? :increment : :decrement
        @counters[name.to_sym] = options

        class_eval <<-EndMethods
          def #{name}
            @#{name} ||= Redis::Atoms::Counter.new(redis, field_key(:#{name}), self.class.counters[:#{name}])
          end
        EndMethods
      end
        
      # Get the current value of the counter. It is more efficient
      # to use the instance method if possible.
      def get_counter(name, id)
        verify_counter_defined!(name)
        initialize_counter!(name, id)
        redis.get(field_key(name, id)).to_i
      end

      # Increment a counter with the specified name and id.  Accepts a block
      # like the instance method.  See Redis::Atoms::Counter for details.
      def increment_counter(name, id, by=1, &block)
        verify_counter_defined!(name)
        initialize_counter!(name, id)
        value = redis.incr(field_key(name, id), by).to_i
        block_given? ? rewindable_block(:decrement_counter, name, id, value, &block) : value
      end

      # Decrement a counter with the specified name and id.  Accepts a block
      # like the instance method.  See Redis::Atoms::Counter for details.
      def decrement_counter(name, id, by=1, &block)
        verify_counter_defined!(name)
        initialize_counter!(name, id)
        value = redis.decr(field_key(name, id), by).to_i
        block_given? ? rewindable_block(:increment_counter, name, id, value, &block) : value
      end

      # Reset a counter to its starting value.
      def reset_counter(name, id, to=nil)
        verify_counter_defined!(name)
        to = @counters[name][:start] if to.nil?
        redis.set(field_key(name, id), to)
      end

      # Define a new lock.  It will function like a model attribute,
      # so it can be used alongside ActiveRecord/DataMapper, etc.
      def lock(name, options={})
        options[:timeout] ||= 5  # seconds
        @locks[name.to_sym] = options
        
        class_eval <<-EndMethods
          def #{name}_lock(&block)
            @#{name}_lock ||= Redis::Atoms::Lock.new(redis, field_key(:#{name}_lock), self.class.locks[:#{name}])
          end
        EndMethods
      end

      # Obtain a lock, and execute the block synchronously.  Any other code
      # (on any server) will spin waiting for the lock up to the :timeout
      # that was specified when the lock was defined.
      def obtain_lock(name, id, &block)
        verify_lock_defined!(name)
        raise ArgumentError, "Missing block to #{self.name}.obtain_lock" unless block_given?
        lock_name = field_key("#{name}_lock", id)
        Redis::Atoms::Lock.new(redis, lock_name, self.class.locks[name]).lock(&block)
      end

      # Clear the lock.  Use with care - usually only in an Admin page to clear
      # stale locks (a stale lock should only happen if a server crashes.)
      def clear_lock(name, id)
        verify_lock_defined!(name)
        lock_name = field_key("#{name}_lock", id)
        redis.del(lock_name)
      end

      private

      def verify_lock_defined!(name)
        raise UndefinedAtom, "Undefined lock :#{name} for class #{self.name}" unless @locks.has_key?(name)
      end

      def verify_counter_defined!(name) #:nodoc:
        raise UndefinedAtom, "Undefined counter :#{name} for class #{self.name}" unless @counters.has_key?(name)
      end

      def initialize_counter!(name, id) #:nodoc:
        key = field_key(name, id)
        unless @initialized_counters[key]
          redis.setnx(key, @counters[name][:start])
        end
        @initialized_counters[key] = true
      end

      # Implements increment/decrement blocks
      def rewindable_block(rewind, name, id, value, &block) #:nodoc:
        raise ArgumentError, "Missing block to rewindable_block somehow" unless block_given?
        ret = nil
        begin
          ret = yield value
        rescue
          send(rewind, name, id)
          raise
        end
        send(rewind, name, id) if ret == false
      end
    end

    # Instance methods that appear in your class when you include Redis::Atoms.
    module InstanceMethods
      def redis() self.class.redis end
      def field_key(name) #:nodoc:
        self.class.field_key(name, id)
      end

      # Increment a counter.
      # It is more efficient to use increment_[counter_name] directly.
      # This is mainly just for completeness to override ActiveRecord.
      def increment(name, by=1)
        send(name).increment(by)
      end

      # Decrement a counter.
      # It is more efficient to use increment_[counter_name] directly.
      # This is mainly just for completeness to override ActiveRecord.
      def decrement(name, by=1)
        send(name).decrement(by)
      end
    end
  end
end

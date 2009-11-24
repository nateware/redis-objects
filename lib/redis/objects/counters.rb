# This is the class loader, for use as "include Redis::Objects::Counters"
# For the object itself, see "Redis::Counter"
require 'redis/counter'
class Redis
  module Objects
    class UndefinedCounter < StandardError; end #:nodoc:
    module Counters
      def self.included(klass)
        klass.instance_variable_set('@counters', {})
        klass.instance_variable_set('@initialized_counters', {})
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      # Class methods that appear in your class when you include Redis::Objects.
      module ClassMethods
        attr_reader :counters, :initialized_counters

        # Define a new counter.  It will function like a regular instance
        # method, so it can be used alongside ActiveRecord, DataMapper, etc.
        def counter(name, options={})
          options[:start] ||= 0
          options[:type]  ||= options[:start] == 0 ? :increment : :decrement
          @counters[name] = options
          class_eval <<-EndMethods
            def #{name}
              @#{name} ||= Redis::Counter.new(field_key(:#{name}), self.class.counters[:#{name}].merge(:redis => redis))
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
        # like the instance method.  See Redis::Objects::Counter for details.
        def increment_counter(name, id, by=1, &block)
          verify_counter_defined!(name)
          initialize_counter!(name, id)
          value = redis.incr(field_key(name, id), by).to_i
          block_given? ? rewindable_block(:decrement_counter, name, id, value, &block) : value
        end

        # Decrement a counter with the specified name and id.  Accepts a block
        # like the instance method.  See Redis::Objects::Counter for details.
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
        
        private
        
        def verify_counter_defined!(name) #:nodoc:
          raise Redis::Objects::UndefinedCounter, "Undefined counter :#{name} for class #{self.name}" unless @counters.has_key?(name)
        end
        
        def initialize_counter!(name, id) #:nodoc:
          key = field_key(name, id)
          unless @initialized_counters[key]
            redis.setnx(key, @counters[name][:start])
          end
          @initialized_counters[key] = true
        end
        
        # Implements increment/decrement blocks on a class level
        def rewindable_block(rewind, name, id, value, &block) #:nodoc:
          # Unfortunately this is almost exactly duplicated from Redis::Counter
          raise ArgumentError, "Missing block to rewindable_block somehow" unless block_given?
          ret = nil
          begin
            ret = yield value
          rescue
            send(rewind, name, id)
            raise
          end
          send(rewind, name, id) if ret.nil?
          ret
        end
      end

      # Instance methods that appear in your class when you include Redis::Objects.
      module InstanceMethods
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
end
# This is the class loader, for use as "include Redis::Objects::Counters"
# For the object itself, see "Redis::Counter"
require 'redis/counter'
class Redis
  module Objects
    class UndefinedCounter < StandardError; end #:nodoc:
    class MissingID < StandardError; end #:nodoc:

    module Counters
      def self.included(klass)
        klass.instance_variable_set('@initialized_counters', {})
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      # Class methods that appear in your class when you include Redis::Objects.
      module ClassMethods
        attr_reader :initialized_counters

        # Define a new counter.  It will function like a regular instance
        # method, so it can be used alongside ActiveRecord, DataMapper, etc.
        def counter(name, options={})
          options[:start] ||= 0
          options[:type]  ||= options[:start] == 0 ? :increment : :decrement
          @redis_objects[name] = options.merge(:type => :counter)
          if options[:global]
            instance_eval <<-EndMethods
              def #{name}
                @#{name} ||= Redis::Counter.new(field_key(:#{name}, ''), redis, @redis_objects[:#{name}])
              end
            EndMethods
            class_eval <<-EndMethods
              def #{name}
                self.class.#{name}
              end
            EndMethods
          else
            class_eval <<-EndMethods
              def #{name}
                @#{name} ||= Redis::Counter.new(field_key(:#{name}), redis, self.class.redis_objects[:#{name}])
              end
            EndMethods
          end
        end

        # Get the current value of the counter. It is more efficient
        # to use the instance method if possible.
        def get_counter(name, id=nil)
          verify_counter_defined!(name, id)
          initialize_counter!(name, id)
          redis.get(field_key(name, id)).to_i
        end

        # Increment a counter with the specified name and id.  Accepts a block
        # like the instance method.  See Redis::Objects::Counter for details.
        def increment_counter(name, id=nil, by=1, &block)
          verify_counter_defined!(name, id)
          initialize_counter!(name, id)
          value = redis.incr(field_key(name, id), by).to_i
          block_given? ? rewindable_block(:decrement_counter, name, id, value, &block) : value
        end

        # Decrement a counter with the specified name and id.  Accepts a block
        # like the instance method.  See Redis::Objects::Counter for details.
        def decrement_counter(name, id=nil, by=1, &block)
          verify_counter_defined!(name, id)
          initialize_counter!(name, id)
          value = redis.decr(field_key(name, id), by).to_i
          block_given? ? rewindable_block(:increment_counter, name, id, value, &block) : value
        end

        # Reset a counter to its starting value.
        def reset_counter(name, id=nil, to=nil)
          verify_counter_defined!(name, id)
          to = @redis_objects[name][:start] if to.nil?
          redis.set(field_key(name, id), to)
        end
        
        private
        
        def verify_counter_defined!(name, id) #:nodoc:
          raise Redis::Objects::UndefinedCounter, "Undefined counter :#{name} for class #{self.name}" unless @redis_objects.has_key?(name)
          if id.nil? and !@redis_objects[name][:global]
            raise Redis::Objects::MissingID, "Missing ID for non-global counter #{self.name}##{name}"
          end
        end
        
        def initialize_counter!(name, id) #:nodoc:
          key = field_key(name, id)
          unless @initialized_counters[key]
            redis.setnx(key, @redis_objects[name][:start])
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
# Use Redis to support atomic operations in your app.
# It maps ruby properties to <tt>model_name:id:field_name</tt> keys in redis.
# It also adds marshaling for string fields and more OOP style access for sets and lists
#
# == Define
#
# require 'redis/model'
# class User < Redis::Model
# value :name, :string
# value :created, :datetime
# value :profile, :json
# list :posts
# set :followers
# end
#
# See Redis::Marshal for more types
#
#
# == Write
#
# u = User.with_key(1)
# u.name = 'Joe' # set user:1:name Joe
# u.created = DateTime.now # set user:1:created 2009-10-05T12:09:56+0400
# u.profile = { # set user:1:profile {"sex":"M","about":"Lorem","age":23}
# :age => 23,
# :sex => 'M',
# :about => 'Lorem'
# }
# u.posts << "Hello world!" # rpush user:1:posts 'Hello world!'
# u.followers << 2 # sadd user:1:followers 2
#
# == Read
#
# u = User.with_key(1)
# p u.name # get user:1:name
# p u.created.strftime('%m/%d/%Y') # get user:1:created
# p u.posts[0,20] # lrange user:1:posts 0 20
# p u.followers.has_key?(2) # sismember user:1:followers 2
#
require 'redis'
class Redis
  module Atoms
    class UndefinedCounter < StandardError; end
    class << self
      def connection=(conn) @connection = conn end
      def connection
        @connection ||= $redis || raise("Redis::Atoms.connection not set")
      end

      def included(klass)
        klass.instance_variable_set('@connection', @connection)
        klass.instance_variable_set('@counters', {})
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end
    end

    module ClassMethods
      attr_accessor :connection
      
      # Set the Redis prefix to use. Defaults to model_name
      def prefix=(prefix) @prefix = prefix end
      def prefix #:nodoc:
        @prefix ||= self.name.to_s.
          sub(%r{(.*::)}, '').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          downcase
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
              connection.setnx(name, #{options[:start]})
              name
            end
          end
          def increment_#{name}(by=1)
            connection.incr(#{name}_counter_name, by).to_i
          end
          def decrement_#{name}(by=1)
            connection.decr(#{name}_counter_name, by).to_i
          end
          def reset_#{name}(to=#{options[:start]})
            connection.set(#{name}_counter_name, to)
          end
          def clear_#{name}  # dangerous/not needed?
            ret = connection.del(#{name}_counter_name)
            @#{name}_counter_name = nil  # triggers setnx
            ret
          end
          def #{name}
            connection.get(#{name}_counter_name).to_i
          end
        EndMethods
      end

      # Get the current value of the counter.
      def get_counter(name, id)
        verify_counter_defined!(name)
        connection.setnx(field_key(name, id), @counters[name][:start])  # have to do each time from the class
        connection.get(field_key(name, id)).to_i
      end

      # Increment a counter with the specified name and id.  It is slightly
      # more efficient to use the model instance method if possible.
      def increment_counter(name, id, by=1)
        verify_counter_defined!(name)
        connection.setnx(field_key(name, id), @counters[name][:start])  # have to do each time from the class
        connection.incr(field_key(name, id), by).to_i
      end

      # Decrement a counter with the specified name and id.  It is slightly
      # more efficient to use the model instance method if possible.
      def decrement_counter(name, id, by=1)
        verify_counter_defined!(name)
        connection.setnx(field_key(name, id), @counters[name][:start])  # have to do each time from the class
        connection.decr(field_key(name, id), by).to_i
      end

      # Reset a counter
      def reset_counter(name, id, to=nil)
        verify_counter_defined!(name)
        to = @counters[name][:start] if to.nil?
        connection.set(field_key(name, id), to)
      end

      def verify_counter_defined!(name)
        raise UndefinedCounter, "Undefined counter :#{name} for class #{self.name}" unless @counters.has_key?(name)
      end

      def field_key(name, id) #:nodoc:
        "#{prefix}:#{id}:#{name}"
      end
    end

    module InstanceMethods
      def connection() self.class.connection end

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

      def field_key(name) #:nodoc:
        self.class.field_key(name, id)
      end
    end
  end
end

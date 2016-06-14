# This is the class loader, for use as "include Redis::Objects::Values"
# For the object itself, see "Redis::Value"
require 'redis/value'
class Redis
  module Objects
    module Values
      def self.included(klass)
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      # Class methods that appear in your class when you include Redis::Objects.
      module ClassMethods
        # Define a new simple value.  It will function like a regular instance
        # method, so it can be used alongside ActiveRecord, DataMapper, etc.
        def value(name, options={})
          redis_objects[name.to_sym] = options.merge(:type => :value)

          mod = Module.new do
            define_method(name) do
              instance_variable_get("@#{name}") or
                instance_variable_set("@#{name}",
                  Redis::Value.new(
                    redis_field_key(name), redis_field_redis(name), redis_options(name)
                  )
                )
            end
            define_method("#{name}=") do |value|
              public_send(name).value = value
            end
          end

          if options[:global]
            extend mod

            # dispatch to class methods
            define_method(name) do
              self.class.public_send(name)
            end
            define_method("#{name}=") do |value|
              self.class.public_send("#{name}=", value)
            end
          else
            include mod
          end
        end

        def mget(name, objects = [])
          return [] if objects.nil? || objects.empty?
          raise "Field name Error" if !redis_objects.keys.include?(name.to_sym)

          keys = objects.map{ |obj| obj.redis_field_key name.to_sym }

          self.redis.mget keys
        end
      end

      # Instance methods that appear in your class when you include Redis::Objects.
      module InstanceMethods
      end
    end
  end
end

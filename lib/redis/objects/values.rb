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
          @redis_objects[name.to_sym] = options.merge(:type => :value)
          klass_name = '::' + self.name
          if options[:global]
            instance_eval <<-EndMethods
              def #{name}
                @#{name} ||= Redis::Value.new(redis_field_key(:#{name}), #{klass_name}.redis, #{klass_name}.redis_objects[:#{name}])
              end
              def #{name}=(value)
                #{name}.value = value
              end
            EndMethods
            class_eval <<-EndMethods
              def #{name}
                self.class.#{name}
              end
              def #{name}=(value)
                self.class.#{name} = value
              end
            EndMethods
          else
            class_eval <<-EndMethods
              def #{name}
                @#{name} ||= Redis::Value.new(redis_field_key(:#{name}), #{klass_name}.redis, #{klass_name}.redis_objects[:#{name}])
              end
              def #{name}=(value)
                #{name}.value = value
              end
            EndMethods
          end
          
        end
      end
      
      # Instance methods that appear in your class when you include Redis::Objects.
      module InstanceMethods
      end
    end
  end
end
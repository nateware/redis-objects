# This is the class loader, for use as "include Redis::Objects::Lists"
# For the object itself, see "Redis::List"
require 'redis/list'
class Redis
  module Objects
    module Lists
      def self.included(klass)
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      # Class methods that appear in your class when you include Redis::Objects.
      module ClassMethods
        # Define a new list.  It will function like a regular instance
        # method, so it can be used alongside ActiveRecord, DataMapper, etc.
        def list(name, options={})
          redis_objects[name.to_sym] = options.merge(:type => :list)
          klass_name = '::' + self.name
          if options[:global]
            instance_eval <<-EndMethods
              def #{name}
                @#{name} ||= Redis::List.new(redis_field_key(:#{name}), #{klass_name}.redis, #{klass_name}.redis_objects[:#{name}])
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
                @#{name} ||= Redis::List.new(redis_field_key(:#{name}), #{klass_name}.redis, #{klass_name}.redis_objects[:#{name}])
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

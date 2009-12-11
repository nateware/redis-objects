# This is the class loader, for use as "include Redis::Objects::Sets"
# For the object itself, see "Redis::Set"
require 'redis/set'
class Redis
  module Objects
    module Sets
      def self.included(klass)
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      # Class methods that appear in your class when you include Redis::Objects.
      module ClassMethods
        # Define a new list.  It will function like a regular instance
        # method, so it can be used alongside ActiveRecord, DataMapper, etc.
        def set(name, options={})
          @redis_objects[name] = options.merge(:type => :set)
          class_eval <<-EndMethods
            def #{name}
              @#{name} ||= Redis::Set.new(field_key(:#{name}), redis, self.class.redis_objects[:#{name}])
            end
          EndMethods
        end
      end

      # Instance methods that appear in your class when you include Redis::Objects.
      module InstanceMethods
      end
    end
  end
end
# This is the class loader, for use as "include Redis::Objects::Sets"
# For the object itself, see "Redis::Set"
require 'redis/set'
class Redis
  module Objects
    module Sets
      def self.included(klass)
        klass.instance_variable_set('@sets', {})
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      # Class methods that appear in your class when you include Redis::Objects.
      module ClassMethods
        attr_reader :sets

        # Define a new list.  It will function like a regular instance
        # method, so it can be used alongside ActiveRecord, DataMapper, etc.
        def set(name, options={})
          @sets[name] = options
          class_eval <<-EndMethods
            def #{name}
              @#{name} ||= Redis::Set.new(field_key(:#{name}), redis, self.class.sets[:#{name}])
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
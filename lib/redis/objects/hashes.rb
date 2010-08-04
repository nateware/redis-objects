# This is the class loader, for use as "include Redis::Objects::Hashes"
# For the object itself, see "Redis::Hash"
require 'redis/dict'
class Redis
  module Objects
    module Hashes
      def self.included(klass)
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      # Class methods that appear in your class when you include Redis::Objects.
      module ClassMethods
        # Define a new dict.  It will function like a regular instance
        # method, so it can be used alongside ActiveRecord, DataMapper, etc.
        def dict(name, options={})
          @redis_objects[name.to_sym] = options.merge(:type => :dict)
          if options[:global]
            instance_eval <<-EndMethods
              def #{name}
                @#{name} ||= Redis::Hash.new(field_key(:#{name}), redis, @redis_objects[:#{name}])
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
                @#{name} ||= Redis::Hash.new(field_key(:#{name}), redis, self.class.redis_objects[:#{name}])
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



class Redis
  module DataTypes
    TYPES = %w(String Integer Float EpochTime DateTime Json Yaml IPAddress FilePath Uri Slug)
    def self.included(klass)
      TYPES.each do |data_type|
        if Object.const_defined?(data_type)
          klass = Object.const_get(data_type)
        else
          klass = Object.const_set(data_type, Class.new)
        end
        if const_defined?(data_type) 
          klass.extend const_get(data_type)
        end
      end
    end

    module String
      def to_redis; to_s; end
    end

    module Integer
      def from_redis(value); value && value.to_i end
    end

    module Float
      def from_redis(value); value && value.to_f end
    end

    module EpochTime
      def to_redis(value)
        value.is_a?(DateTime) ? value.to_time.to_i : value.to_i
      end
    
      def from_redis(value) Time.at(value.to_i) end
    end

    module DateTime
      def to_redis(value); value.strftime('%FT%T%z')                        end
      def from_redis(value); value && ::DateTime.strptime(value, '%FT%T%z') end
    end

    module Json
      def to_redis(value); Yajl::Encoder.encode(value)          end
      def from_redis(value); value && Yajl::Parser.parse(value) end
    end
  
    module Yaml
      def to_redis(value); Yaml.dump(value)    end
      def from_redis(value); Yaml.load(value)  end
    end
  
    module IPAddress      
      def from_redis(value)
        return nil if value.nil?
        if value.is_a?(String)
          IPAddr.new(value.empty? ? '0.0.0.0' : value)
        else
          raise "+value+ must be nil or a String"
        end
      end
    end
  
    module FilePath
      require 'pathname'
      def from_redis(value)
        value.blank? ? nil : Pathname.new(value)
      end
    end
  
    module Uri
      require 'addressable/uri'
      def from_redis(value)
        Addressable::URI.parse(value)
      end
    end
  
    module Slug
      require 'addressable/uri'
      def to_redis(value)
        Addressable::URI.parse(value).display_uri
      end
    end
  end
end
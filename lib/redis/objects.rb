# Redis::Objects - Lightweight object layer around redis-rb
# See README.rdoc for usage and approach.
require 'redis'
class Redis
  #
  # Redis::Objects enables high-performance atomic operations in your app
  # by leveraging the atomic features of the Redis server.  To use Redis::Objects,
  # first include it in any class you want.  (This example uses an ActiveRecord
  # subclass, but that is *not* required.) Then, use +counter+, +lock+, +set+, etc
  # to define your primitives:
  #
  #   class Game < ActiveRecord::Base
  #     include Redis::Objects
  #
  #     counter :joined_players
  #     counter :active_players, :key => 'game:#{id}:act_plyr'
  #     lock :archive_game
  #     set :player_ids
  #   end
  # 
  # The, you can use these counters both for bookeeping and as atomic actions:
  #
  #   @game = Game.find(id)
  #   @game_user = @game.joined_players.increment do |val|
  #     break if val > @game.max_players
  #     gu = @game.game_users.create!(:user_id => @user.id)
  #     @game.active_players.increment
  #     gu
  #   end
  #   if @game_user.nil?
  #     # game is full - error screen
  #   else
  #     # success
  #   end
  #
  #
  #
  module Objects
    dir = File.expand_path(__FILE__.sub(/\.rb$/,''))

    autoload :Counters, File.join(dir, 'counters')
    autoload :Lists, File.join(dir, 'lists')
    autoload :Locks, File.join(dir, 'locks')
    autoload :Sets, File.join(dir, 'sets')
    autoload :SortedSets, File.join(dir, 'sorted_sets')
    autoload :Values, File.join(dir, 'values')
    autoload :Hashes, File.join(dir, 'hashes')

    class NotConnected < StandardError; end
    class NilObjectId  < StandardError; end

    class << self
      def redis=(conn) @redis = conn end
      def redis
        @redis ||= $redis || Redis.current || raise(NotConnected, "Redis::Objects.redis not set to a Redis.new connection")
      end

      def included(klass)
        # Core (this file)
        klass.instance_variable_set('@redis', @redis)
        klass.instance_variable_set('@redis_objects', {})
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
        
        # Pull in each object type
        klass.send :include, Redis::Objects::Counters
        klass.send :include, Redis::Objects::Lists
        klass.send :include, Redis::Objects::Locks
        klass.send :include, Redis::Objects::Sets
        klass.send :include, Redis::Objects::SortedSets
        klass.send :include, Redis::Objects::Values
        klass.send :include, Redis::Objects::Hashes
      end
    end

    # Class methods that appear in your class when you include Redis::Objects.
    module ClassMethods
      attr_writer   :redis
      attr_accessor :redis_objects
      def redis() @redis ||= Objects.redis end

      # Set the Redis redis_prefix to use. Defaults to model_name
      def redis_prefix=(redis_prefix) @redis_prefix = redis_prefix end
      def redis_prefix(klass = self) #:nodoc:
        @redis_prefix ||= klass.name.to_s.
          sub(%r{(.*::)}, '').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          downcase
      end

      def redis_field_key(name, id=nil) #:nodoc:
        klass = first_ancestor_with(name)
        # This can never ever ever ever change or upgrades will corrupt all data
        # to comment above: I don't think people where using Proc as keys before (that would create a weird key). Should be ok
        key = klass.redis_objects[name.to_sym][:key]
        if key && key.respond_to?(:call)
          key = key.call self
        end
        if id.nil? and !klass.redis_objects[name.to_sym][:global]
          raise NilObjectId,
            "Attempt to address redis-object :#{name} on class #{klass.name} with nil id (unsaved record?) [object_id=#{object_id}]"
        end
        key || "#{redis_prefix(klass)}:#{id}:#{name}"
      end

      def first_ancestor_with(name)
        if redis_objects && redis_objects.key?(name.to_sym)
          self
        elsif superclass && superclass.respond_to?(:redis_objects)
          superclass.first_ancestor_with(name)
        end
      end
    end

    # Instance methods that appear in your class when you include Redis::Objects.
    module InstanceMethods
      def redis() self.class.redis end
      def redis_field_key(name) #:nodoc:
        klass = self.class.first_ancestor_with(name)
        if key = klass.redis_objects[name.to_sym][:key]
          if key.respond_to?(:call)
            key.call self
          else
            eval "%(#{key})"
          end
        else
          if id.nil? and !klass.redis_objects[name.to_sym][:global]
            raise NilObjectId,
              "Attempt to address redis-object :#{name} on class #{klass.name} with nil id (unsaved record?) [object_id=#{object_id}]"
          end
          # don't try to refactor into class redis_field_key because fucks up eval context
          "#{klass.redis_prefix}:#{id}:#{name}"
        end
      end
    end
  end
end

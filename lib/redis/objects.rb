# Redis::Objects - Lightweight object layer around redis-rb
# See README.rdoc for usage and approach.
require 'redis'
require 'redis/objects/connection_pool_proxy'

class Redis
  autoload :Counter,   'redis/counter'
  autoload :List,      'redis/list'
  autoload :Lock,      'redis/lock'
  autoload :Set,       'redis/set'
  autoload :SortedSet, 'redis/sorted_set'
  autoload :Value,     'redis/value'
  autoload :HashKey,   'redis/hash_key'

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
  # The, you can use these counters both for bookkeeping and as atomic actions:
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

    autoload :Counters,   'redis/objects/counters'
    autoload :Lists,      'redis/objects/lists'
    autoload :Locks,      'redis/objects/locks'
    autoload :Sets,       'redis/objects/sets'
    autoload :SortedSets, 'redis/objects/sorted_sets'
    autoload :Values,     'redis/objects/values'
    autoload :Hashes,     'redis/objects/hashes'

    class NotConnected < StandardError; end
    class NilObjectId  < StandardError; end

    class << self
      def redis=(conn)
        @redis = Objects::ConnectionPoolProxy.proxy_if_needed(conn)
      end
      def redis
        @redis || $redis || Redis.current ||
          raise(NotConnected, "Redis::Objects.redis not set to a Redis.new connection")
      end

      def included(klass)
        # Core (this file)
        klass.instance_variable_set('@redis', nil)
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
      # Enable per-class connections (eg, User and Post can use diff redis-server)
      def redis=(conn)
        @redis = Objects::ConnectionPoolProxy.proxy_if_needed(conn)
      end

      def redis
        @redis || Objects.redis
      end

      # Internal list of objects
      attr_writer :redis_objects
      def redis_objects
        @redis_objects ||= {}
      end

      # Set the Redis redis_prefix to use. Defaults to model_name
      def redis_prefix=(redis_prefix) @redis_prefix = redis_prefix end
      def redis_prefix(klass = self) #:nodoc:
        @redis_prefix ||= klass.name.to_s.
          sub(%r{(.*::)}, '').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          downcase
      end

      def redis_options(name)
        klass = first_ancestor_with(name)
        return klass.redis_objects[name.to_sym] || {}
      end

      def redis_field_redis(name) #:nodoc:
        klass = first_ancestor_with(name)
        override_redis = klass.redis_objects[name.to_sym][:redis]
        if override_redis
          Objects::ConnectionPoolProxy.proxy_if_needed(override_redis)
        else
          self.redis
        end
      end

      def redis_field_key(name, id=nil, context=self) #:nodoc:
        klass = first_ancestor_with(name)
        # READ THIS: This can never ever ever ever change or upgrades will corrupt all data
        # I don't think people were using Proc as keys before (that would create a weird key). Should be ok
        if key = klass.redis_objects[name.to_sym][:key]
          if key.respond_to?(:call)
            key = key.call context
          else
            context.instance_eval "%(#{key})"
          end
        else
          if id.nil? and !klass.redis_objects[name.to_sym][:global]
            raise NilObjectId,
              "[#{klass.redis_objects[name.to_sym]}] Attempt to address redis-object " +
              ":#{name} on class #{klass.name} with nil id (unsaved record?) [object_id=#{object_id}]"
          end
          "#{redis_prefix(klass)}:#{id}:#{name}"
        end
      end

      def first_ancestor_with(name)
        if redis_objects && redis_objects.key?(name.to_sym)
          self
        elsif superclass && superclass.respond_to?(:redis_objects)
          superclass.first_ancestor_with(name)
        end
      end

      def redis_id_field(id=nil)
        @redis_id_field = id || @redis_id_field

        if superclass && superclass.respond_to?(:redis_id_field)
          @redis_id_field ||= superclass.redis_id_field
        end

        @redis_id_field ||= :id
      end
    end

    # Instance methods that appear in your class when you include Redis::Objects.
    module InstanceMethods
      # Map up one level to make modular extend/include approach sane
      def redis()         self.class.redis end
      def redis_objects() self.class.redis_objects end

      def delete!
        redis.del(redis_objects.keys.map { |k| send(k) }.reject(&:nil?).map { |obj| obj.key })
      end

      def redis_options(name) #:nodoc:
        return self.class.redis_options(name)
      end

      def redis_field_redis(name) #:nodoc:
        return self.class.redis_field_redis(name)
      end

      def redis_field_key(name) #:nodoc:
        id = send(self.class.redis_id_field)
        self.class.redis_field_key(name, id, self)
      end
    end
  end
end

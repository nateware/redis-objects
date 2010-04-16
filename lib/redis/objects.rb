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

    class NotConnected  < StandardError; end

    class << self
      def redis=(conn) @redis = conn end
      def redis
        @redis ||= $redis || raise(NotConnected, "Redis::Objects.redis not set to a Redis.new connection")
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
      end
    end

    # Class methods that appear in your class when you include Redis::Objects.
    module ClassMethods
      attr_accessor :redis, :redis_objects

      # Set the Redis prefix to use. Defaults to model_name
      def prefix=(prefix) @prefix = prefix end
      def prefix #:nodoc:
        @prefix ||= self.name.to_s.
          sub(%r{(.*::)}, '').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          downcase
      end

      def field_key(name, id='') #:nodoc:
        # This can never ever ever ever change or upgrades will corrupt all data
        @redis_objects[name.to_sym][:key] || "#{prefix}:#{id}:#{name}"
      end
    end

    # Instance methods that appear in your class when you include Redis::Objects.
    module InstanceMethods
      def redis() self.class.redis end
      def field_key(name) #:nodoc:
        # This can never ever ever ever change or upgrades will corrupt all data
        if key = self.class.redis_objects[name.to_sym][:key]
          eval "%(#{key})"
        else
          # don't try to refactor into class field_key because fucks up eval context
          "#{self.class.prefix}:#{id}:#{name}"
        end
      end
    end
  end
end

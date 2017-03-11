require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a Redis counter.  This functions like a proxy class, in
  # that you can say @object.counter_name to get the value and then
  # @object.counter_name.increment to operate on it.  You can use this
  # directly, or you can use the counter :foo class method in your
  # class to define a counter.
  #
  class Counter < BaseObject
    require 'redis/helpers/core_commands'
    include Redis::Helpers::CoreCommands

    attr_reader :key, :options
    def initialize(key, *args)
      super(key, *args)
      @options[:start] ||= @options[:default] || 0
      raise ArgumentError, "Marshalling redis counters does not make sense" if @options[:marshal]
      redis.setnx(key, @options[:start]) unless @options[:start] == 0 || @options[:init] === false
    end

    # Reset the counter to its starting value.  Not atomic, so use with care.
    # Normally only useful if you're discarding all sub-records associated
    # with a parent and starting over (for example, restarting a game and
    # disconnecting all players).
    def reset(to=options[:start])
      allow_expiration do
        redis.set key, to.to_i
        true  # hack for redis-rb regression
      end
    end

    # Reset the counter to its starting value, and return previous value.
    # Use this to "reap" the counter and save it somewhere else. This is
    # atomic in that no increments or decrements are lost if you process
    # the returned value.
    def getset(to=options[:start])
      redis.getset(key, to.to_i).to_i
    end

    # Returns the current value of the counter.  Normally just calling the
    # counter will lazily fetch the value, and only update it if increment
    # or decrement is called.  This forces a network call to redis-server
    # to get the current value.
    def value
      redis.get(key).to_i
    end
    alias_method :get, :value

    def value=(val)
      allow_expiration do
        if val.nil?
          delete
        else
          redis.set key, val
        end
      end
    end
    alias_method :set, :value=

    # Like .value but casts to float since Redis addresses these differently.
    def to_f
      redis.get(key).to_f
    end

    # Increment the counter atomically and return the new value.  If passed
    # a block, that block will be evaluated with the new value of the counter
    # as an argument. If the block returns nil or throws an exception, the
    # counter will automatically be decremented to its previous value.  This
    # method is aliased as incr() for brevity.
    def increment(by=1, &block)
      allow_expiration do
        val = redis.incrby(key, by).to_i
        block_given? ? rewindable_block(:decrement, by, val, &block) : val
      end
    end
    alias_method :incr, :increment
    alias_method :incrby, :increment

    # Decrement the counter atomically and return the new value.  If passed
    # a block, that block will be evaluated with the new value of the counter
    # as an argument. If the block returns nil or throws an exception, the
    # counter will automatically be incremented to its previous value.  This
    # method is aliased as decr() for brevity.
    def decrement(by=1, &block)
      allow_expiration do
        val = redis.decrby(key, by).to_i
        block_given? ? rewindable_block(:increment, by, val, &block) : val
      end
    end
    alias_method :decr, :decrement
    alias_method :decrby, :decrement

    # Increment a floating point counter atomically.
    # Redis uses separate API's to interact with integers vs floats.
    def incrbyfloat(by=1.0, &block)
      allow_expiration do
        val = redis.incrbyfloat(key, by).to_f
        block_given? ? rewindable_block(:decrbyfloat, by, val, &block) : val
      end
    end

    # Decrement a floating point counter atomically.
    # Redis uses separate API's to interact with integers vs floats.
    def decrbyfloat(by=1.0, &block)
      allow_expiration do
        val = redis.incrbyfloat(key, -by).to_f
        block_given? ? rewindable_block(:incrbyfloat, -by, val, &block) : val
      end
    end

    ##
    # Proxy methods to help make @object.counter == 10 work
    def to_s; value.to_s; end
    alias_method :to_i, :value
    def nil?; value.nil? end

    # This needs to handle +/- either actual integers or other Redis::Counters
    def -(what)
      value.to_i - what.to_i
    end
    def +(what)
      value.to_i - what.to_i
    end

    # Math ops
    %w(== < > <= >=).each do |m|
      class_eval <<-EndOverload
        def #{m}(x)
          value #{m} x
        end
      EndOverload
    end

    private

    # Implements atomic increment/decrement blocks
    def rewindable_block(rewind, by, value, &block)
      raise ArgumentError, "Missing block to rewindable_block somehow" unless block_given?
      ret = nil
      begin
        ret = yield value
      rescue
        send(rewind, by)
        raise
      end
      send(rewind, by) if ret.nil?
      ret
    end
  end
end

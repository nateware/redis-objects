class Redis
  #
  # Class representing a counter.  This functions like a proxy class, in
  # that you can say @object.counter_name to get the value and also
  # @object.counter_name.increment to operate on it.  You can use this
  # directly, or you can use the counter :foo class method in your
  # class to define a counter.
  #
  class Counter
    attr_reader :key, :value, :options, :redis
    def initialize(key, options={})
      @key = key
      @options = options
      @redis = options[:redis] || Redis::Objects.redis
      @options[:start] ||= 0
      @options[:type]  ||= @options[:start] == 0 ? :increment : :decrement
      @redis.setnx(key, @options[:start]) unless @options[:start] == 0 || @options[:init] === false
    end

    # Reset the counter to its starting value.  Not atomic, so use with care.
    # Normally only useful if you're discarding all sub-records associated
    # with a parent and starting over (for example, restarting a game and
    # disconnecting all players).
    def reset(to=options[:start])
      redis.set(key, to.to_i)
      @value = to.to_i
    end

    # Gets the current value of the counter.  Normally just calling the
    # counter will lazily fetch the value, and only update it if increment
    # or decrement is called.  This forces a network call to redis-server
    # to get the current value.
    def get
      @value = redis.get(key).to_i
    end
    
    # Increment the counter atomically and return the new value.  If passed
    # a block, that block will be evaluated with the new value of the counter
    # as an argument. If the block returns nil or throws an exception, the
    # counter will automatically be decremented to its previous value.  This
    # method is aliased as incr() for brevity.
    def increment(by=1, &block)
      @value = redis.incr(key, by).to_i
      block_given? ? rewindable_block(:decrement, @value, &block) : @value
    end
    alias_method :incr, :increment

    # Decrement the counter atomically and return the new value.  If passed
    # a block, that block will be evaluated with the new value of the counter
    # as an argument. If the block returns nil or throws an exception, the
    # counter will automatically be incremented to its previous value.  This
    # method is aliased as incr() for brevity.
    def decrement(by=1, &block)
      @value = redis.decr(key, by).to_i
      block_given? ? rewindable_block(:increment, @value, &block) : @value
    end
    alias_method :decr, :decrement

    ##
    # Proxy methods to help make @object.counter == 10 work
    def to_i #:nodoc:
      @value ||= get
    end

    def to_s #:nodoc:
      (@value ||= get).to_s
    end
    alias_method :to_str, :to_s

    # Math ops
    %w(== < > <= >= ==).each do |m|
      class_eval <<-EndOverload
        def #{m}(x)
          to_i #{m} x
        end
      EndOverload
    end
   
    private
    
    # Implements increment/decrement blocks
    def rewindable_block(rewind, value, &block)
      raise ArgumentError, "Missing block to rewindable_block somehow" unless block_given?
      ret = nil
      begin
        ret = yield value
      rescue
        send(rewind)
        raise
      end
      send(rewind) if ret.nil?
      ret
    end
  end
end


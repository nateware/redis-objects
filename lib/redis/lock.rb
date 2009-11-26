class Redis
  #
  # Class representing a lock.  This functions like a proxy class, in
  # that you can say @object.lock_name { block } to use the lock and also
  # @object.counter_name.clear to reset on it.  You can use this
  # directly, but it is better to use the lock :foo class method in your
  # class to define a lock.
  #
  class Lock
    class LockTimeout < StandardError; end #:nodoc:

    attr_reader :key, :options, :redis
    def initialize(key, redis=$redis, options={})
      @key = key
      @redis = redis
      @options = options
      @options[:timeout] ||= 5
      @redis.setnx(key, @options[:start]) unless @options[:start] == 0 || @options[:init] === false
    end

    # Clear the lock.  Should only be needed if there's a server crash
    # or some other event that gets locks in a stuck state.
    def clear
      redis.del(key)
    end
    alias_method :delete, :clear

    # Get the lock and execute the code block. Any other code that needs the lock
    # (on any server) will spin waiting for the lock up to the :timeout
    # that was specified when the lock was defined.
    def lock(&block)
      start = Time.now
      gotit = false
      while Time.now - start < @options[:timeout]
        gotit = redis.setnx(key, 1)
        break if gotit
        sleep 0.1
      end
      raise LockTimeout, "Timeout on lock #{key} exceeded #{@options[:timeout]} sec" unless gotit
      begin
        yield
      ensure
        redis.del(key)
      end
    end
  end
end
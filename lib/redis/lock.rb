require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a lock.  This functions like a proxy class, in
  # that you can say @object.lock_name { block } to use the lock and also
  # @object.counter_name.clear to reset on it.  You can use this
  # directly, but it is better to use the lock :foo class method in your
  # class to define a lock.
  #
  class Lock < BaseObject
    class LockTimeout < StandardError; end #:nodoc:

    attr_reader :key, :options
    def initialize(key, *args)
      super(key, *args)
      @options[:timeout] ||= 5
      @options[:init] = false if @options[:init].nil? # default :init to false
      redis.setnx(key, @options[:start]) unless @options[:start] == 0 || @options[:init] === false
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
      expiration = nil
      while Time.now - start < @options[:timeout]
        expiration = generate_expiration
        # Use the expiration as the value of the lock.
        gotit = redis.setnx(key, expiration)
        break if gotit

        # Lock is being held.  Now check to see if it's expired (if we're using
        # lock expiration).
        # See "Handling Deadlocks" section on http://redis.io/commands/setnx
        if !@options[:expiration].nil?
          old_expiration = redis.get(key).to_f

          if old_expiration < Time.now.to_f
            # If it's expired, use GETSET to update it.
            expiration = generate_expiration
            old_expiration = redis.getset(key, expiration).to_f

            # Since GETSET returns the old value of the lock, if the old expiration
            # is still in the past, we know no one else has expired the locked
            # and we now have it.
            if old_expiration < Time.now.to_f
              gotit = true
              break
            end
          end
        end

        sleep 0.1
      end
      raise LockTimeout, "Timeout on lock #{key} exceeded #{@options[:timeout]} sec" unless gotit
      begin
        yield
      ensure
        # We need to be careful when cleaning up the lock key.  If we took a really long
        # time for some reason, and the lock expired, someone else may have it, and
        # it's not safe for us to remove it.  Check how much time has passed since we
        # wrote the lock key and only delete it if it hasn't expired (or we're not using
        # lock expiration)
        if @options[:expiration].nil? || expiration > Time.now.to_f
          redis.del(key)
        end
      end
    end

    def generate_expiration
      @options[:expiration].nil? ? 1 : (Time.now + @options[:expiration].to_f + 1).to_f
    end
  end
end

require File.dirname(__FILE__) + '/base_object'
require 'securerandom'

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

    RELEASE_LOCK_SCRIPT = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end".freeze

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

    def value
      nil
    end

    # Get the lock and execute the code block. Any other code that needs the lock
    # (on any server) will spin waiting for the lock up to the :timeout
    # that was specified when the lock was defined.
    def lock
      raise ArgumentError, 'Block not given' unless block_given?
      expiration_ms = generate_expiration
      expiration_s  = expiration_ms / 1000.0
      end_time = nil
      lock_id = SecureRandom.uuid
      try_until_timeout do
        end_time = Time.now.to_i + expiration_s
        # Set a NX record and use the Redis expiration mechanism.
        # Empty value because the presence of it is enough to lock
        # `px` only except an Integer in millisecond
        break if redis.set(key, lock_id, px: expiration_ms, nx: true)

        # Backward compatibility code
        # TODO: remove at the next major release for performance
        unless @options[:expiration].nil?
          old_expiration = redis.get(key).to_f

          # Check it was not an empty string with `zero?` and
          # the expiration time is passed.
          if !old_expiration.zero? && old_expiration < Time.now.to_f
            expiration_ms = generate_expiration
            expiration_s  = expiration_ms / 1000.0
            end_time = Time.now.to_i + expiration_s
            break if redis.set(key, lock_id, px: expiration_ms)
          end
        end
      end
      begin
        yield
      ensure
        release_lock(key, lock_id, end_time)
      end
    end

    # Return expiration in milliseconds
    def generate_expiration
      ((@options[:expiration].nil? ? 1 : @options[:expiration].to_f) * 1000).to_i
    end

    private

    def try_until_timeout
      if @options[:timeout] == 0
        yield
      else
        start = Time.now
        while Time.now - start < @options[:timeout]
          yield
          sleep 0.1
        end
      end
      raise LockTimeout, "Timeout on lock #{key} exceeded #{@options[:timeout]} sec"
    end

    def release_lock(key, lock_id, end_time)
      return unless @options[:expiration].nil? || end_time > Time.now.to_f
      redis.eval(RELEASE_LOCK_SCRIPT, [key], [lock_id])
    end
  end
end

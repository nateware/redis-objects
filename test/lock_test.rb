require File.dirname(__FILE__) + '/test_helper'

class LockTest < Test::Unit::TestCase

  def setup
    Redis::Objects.redis.flushall
  end

  def test_lock_expiration_is_set
    start = Time.now
    expiry = 15
    lock = Redis::Lock.new(:test_lock, $redis, :expiration => expiry, :init => false)
    lock.lock do
      expiration = $redis.get("test_lock").to_f

      # The expiration stored in redis should be 15 seconds from when we started
      # or a little more
      assert(expiration >= (start + expiry).to_f)

      # Make sure it's no more then a couple seconds from when we started, since
      # we don't know the exact ms when it was written
      assert(expiration <= (start + expiry + 2).to_f)
    end

    # key should have been cleaned up
    assert_nil($redis.get("test_lock"))
  end

  def test_expiration_is_1_when_no_expiration_is_set
    lock = Redis::Lock.new(:test_lock, $redis, :init => false)
    lock.lock do
      assert_equal('1', $redis.get('test_lock'))
    end

    # key should have been cleaned up
    assert_nil($redis.get("test_lock"))
  end

  def test_expired_lock_is_gettable
    expiry = 15
    lock = Redis::Lock.new(:test_lock, $redis, :expiration => expiry, :timeout => 0.1, :init => false)

    # create a fake lock in the past
    $redis.set("test_lock", Time.now-(expiry + 60))

    gotit = false
    lock.lock do
      gotit = true
    end

    # should get the lock because it has expired
    assert(gotit)
    assert_nil($redis.get("test_lock"))
  end

  def test_non_expired_lock_is_not_gettable
    expiry = 15
    lock = Redis::Lock.new(:test_lock, $redis, :expiration => expiry, :timeout => 0.1, :init => false)

    # create a fake lock
    $redis.set("test_lock", (Time.now + expiry).to_f)

    gotit = false
    assert_raises Redis::Lock::LockTimeout do
      lock.lock do
        gotit = true
      end
    end

    # should not have the lock
    assert(!gotit)
    # lock value should still be set
    assert($redis.get("test_lock"))
  end

  def test_key_is_not_removed_if_lock_is_held_past_expiration
    lock = Redis::Lock.new(:test_lock, $redis, :expiration => 0.0, :init => false)

    lock.lock do
      sleep 1.1
    end

    # lock value should still be set since the lock was held for more than the expiry
    assert($redis.get("test_lock"))
  end

end
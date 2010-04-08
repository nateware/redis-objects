
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/counter'
require 'redis/list'
require 'redis/value'
require 'redis/lock'
require 'redis/set'
require 'redis/sorted_set'

describe Redis::Value do
  before :all do
    @value = Redis::Value.new('spec/value')
  end

  before :each do
    @value.delete
  end

  it "should handle simple values" do
    @value.should == nil
    @value.value = 'Trevor Hoffman'
    @value.should == 'Trevor Hoffman'
    @value.get.should == 'Trevor Hoffman'
    @value.del.should be_true
    @value.should be_nil
  end

  it "should handle complex marshaled values" do
    @value.should == nil
    @value.value = {:json => 'data'}
    @value.should == {:json => 'data'}
    @value.get.should == {:json => 'data'}
    @value.value = [[1,2], {:t3 => 4}]
    @value.should == [[1,2], {:t3 => 4}]
    @value.get.should == [[1,2], {:t3 => 4}]
    @value.del.should be_true
    @value.should be_nil
  end

  it "should support renaming values" do
    @value.value = 'Peter Pan'
    @value.key.should == 'spec/value'
    @value.rename('spec/value2').should be_true
    @value.key.should == 'spec/value2'
    @value.should == 'Peter Pan'
    old = Redis::Value.new('spec/value')
    old.should be_nil
    old.value = 'Tuff'
    @value.renamenx('spec/value').should be_false
    @value.value.should == 'Peter Pan'
  end

  after :all do
    @value.delete
  end
end


describe Redis::List do
  before :all do
    @list = Redis::List.new('spec/list')
  end

  before :each do
    @list.clear
  end

  it "should handle lists of simple values" do
    @list.should be_empty
    @list << 'a'
    @list.should == ['a']
    @list.get.should == ['a']
    @list.unshift 'b'
    @list.to_s.should == 'b, a'
    @list.should == ['b','a']
    @list.get.should == ['b','a']
    @list.push 'c'
    @list.should == ['b','a','c']
    @list.get.should == ['b','a','c']
    @list.first.should == 'b'
    @list.last.should == 'c'
    @list << 'd'
    @list.should == ['b','a','c','d']
    @list[1].should == 'a'
    @list[0].should == 'b'
    @list[2].should == 'c'
    @list[3].should == 'd'
    @list.include?('c').should be_true
    @list.include?('no').should be_false
    @list.pop.should == 'd'
    @list[0].should == @list.at(0)
    @list[1].should == @list.at(1)
    @list[2].should == @list.at(2)
    @list.should == ['b','a','c']
    @list.get.should == ['b','a','c']
    @list.shift.should == 'b'
    @list.should == ['a','c']
    @list.get.should == ['a','c']
    @list << 'e' << 'f' << 'e'
    @list.should == ['a','c','e','f','e']
    @list.get.should == ['a','c','e','f','e']
    @list.delete('e').should == 2
    @list.should == ['a','c','f']
    @list.get.should == ['a','c','f']
    @list << 'j'
    @list.should == ['a','c','f','j']
    @list[0..2].should == ['a','c','f']
    @list[1, 3].should == ['c','f','j']
    @list.length.should == 4
    @list.size.should == 4
    @list.should == ['a','c','f','j']
    @list.get.should == ['a','c','f','j']

    i = -1
    @list.each do |st|
      st.should == @list[i += 1]
    end
    @list.should == ['a','c','f','j']
    @list.get.should == ['a','c','f','j']

    @list.each_with_index do |st,i|
      st.should == @list[i]
    end
    @list.should == ['a','c','f','j']
    @list.get.should == ['a','c','f','j']

    coll = @list.collect{|st| st}
    coll.should == ['a','c','f','j']
    @list.should == ['a','c','f','j']
    @list.get.should == ['a','c','f','j']

    @list << 'a'
    coll = @list.select{|st| st == 'a'}
    coll.should == ['a','a']
    @list.should == ['a','c','f','j','a']
    @list.get.should == ['a','c','f','j','a']
  end

  it "should handle lists of complex data types" do
    @list << {:json => 'data'}
    @list << {:json2 => 'data2'}
    @list.first.should == {:json => 'data'}
    @list.last.should == {:json2 => 'data2'}
    @list << [1,2,3,[4,5]]
    @list.last.should == [1,2,3,[4,5]]
    @list.shift.should == {:json => 'data'}
  end
  
  it "should support renaming lists" do
    @list.should be_empty
    @list << 'a' << 'b' << 'a' << 3
    @list.should == ['a','b','a','3']
    @list.key.should == 'spec/list'
    @list.rename('spec/list3', false).should be_true
    @list.key.should == 'spec/list'
    @list.redis.del('spec/list3')
    @list << 'a' << 'b' << 'a' << 3
    @list.rename('spec/list2').should be_true
    @list.key.should == 'spec/list2'
    @list.redis.lrange(@list.key, 0, 3).should == ['a','b','a','3']
    old = Redis::List.new('spec/list')
    old.should be_empty
    old << 'Tuff'
    old.values.should == ['Tuff']
    @list.renamenx('spec/list').should be_false
    @list.renamenx(old).should be_false
    @list.renamenx('spec/foo').should be_true
    old.values.should == ['Tuff']
    @list.clear
    @list.redis.del('spec/list2')
  end

  after :all do
    @list.clear
  end
end

describe Redis::Counter do
  before :all do
    @counter  = Redis::Counter.new('spec/counter')
    @counter2 = Redis::Counter.new('spec/counter')
  end

  before :each do
    @counter.reset
  end

  it "should support increment/decrement of counters" do
    @counter.key.should == 'spec/counter'
    @counter.incr(10)
    @counter.should == 10
    
    # math proxy ops
    (@counter == 10).should be_true
    (@counter <= 10).should be_true
    (@counter < 11).should be_true
    (@counter > 9).should be_true
    (@counter >= 10).should be_true
    "#{@counter}".should == "10"

    @counter.increment.should == 11
    @counter.increment.should == 12
    @counter2.increment.should == 13
    @counter2.increment(2).should == 15
    @counter.decrement.should == 14
    @counter2.decrement.should == 13
    @counter.decrement.should == 12
    @counter2.decrement(4).should == 8
    @counter.should == 8
    @counter.reset.should be_true
    @counter.should == 0
    @counter.reset(15).should be_true
    @counter.should == 15
  end

  after :all do
    @counter.delete
  end
end

describe Redis::Lock do
  before :each do
    $redis.flushall
  end

  it "should set the value to the expiration" do
    start = Time.now
    expiry = 15
    lock = Redis::Lock.new(:test_lock, $redis, :expiration => expiry, :init => false)
    lock.lock do
      expiration = $redis.get("test_lock").to_f

      # The expiration stored in redis should be 15 seconds from when we started
      # or a little more
      expiration.should be_close((start + expiry).to_f, 2.0)
    end

    # key should have been cleaned up
    $redis.get("test_lock").should be_nil
  end

  it "should set value to 1 when no expiration is set" do
    lock = Redis::Lock.new(:test_lock, $redis, :init => false)
    lock.lock do
      $redis.get('test_lock').should == '1'
    end

    # key should have been cleaned up
    $redis.get("test_lock").should be_nil
  end

  it "should let lock be gettable when lock is expired" do
    expiry = 15
    lock = Redis::Lock.new(:test_lock, $redis, :expiration => expiry, :timeout => 0.1, :init => false)

    # create a fake lock in the past
    $redis.set("test_lock", Time.now-(expiry + 60))

    gotit = false
    lock.lock do
      gotit = true
    end

    # should get the lock because it has expired
    gotit.should be_true
    $redis.get("test_lock").should be_nil
  end

  it "should not let non-expired locks be gettable" do
    expiry = 15
    lock = Redis::Lock.new(:test_lock, $redis, :expiration => expiry, :timeout => 0.1, :init => false)

    # create a fake lock
    $redis.set("test_lock", (Time.now + expiry).to_f)

    gotit = false
    error = nil
    begin
      lock.lock do
        gotit = true
      end
    rescue => error
    end

    error.should be_kind_of(Redis::Lock::LockTimeout)

    # should not have the lock
    gotit.should_not be_true

    # lock value should still be set
    $redis.get("test_lock").should_not be_nil
  end

  it "should not remove the key if lock is held past expiration" do
    lock = Redis::Lock.new(:test_lock, $redis, :expiration => 0.0, :init => false)

    lock.lock do
      sleep 1.1
    end

    # lock value should still be set since the lock was held for more than the expiry
    $redis.get("test_lock").should_not be_nil
  end
end

describe Redis::Set do
  before :all do
    @set = Redis::Set.new('spec/set')
    @set_1 = Redis::Set.new('spec/set_1')
    @set_2 = Redis::Set.new('spec/set_2')
    @set_3 = Redis::Set.new('spec/set_3')
  end

  before :each do
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
  end

  it "should handle sets of simple values" do
    @set.should be_empty
    @set << 'a' << 'a' << 'a'
    @set.should == ['a']
    @set.get.should == ['a']
    @set << 'b' << 'b'
    @set.to_s.should == 'a, b'
    @set.should == ['a','b']
    @set.members.should == ['a','b']
    @set.get.should == ['a','b']
    @set << 'c'
    @set.sort.should == ['a','b','c']
    @set.get.sort.should == ['a','b','c']
    @set.delete('c')
    @set.should == ['a','b']
    @set.get.sort.should == ['a','b']
    @set.length.should == 2
    @set.size.should == 2
    
    i = 0
    @set.each do |st|
      i += 1
    end
    i.should == @set.length

    coll = @set.collect{|st| st}
    coll.should == ['a','b']
    @set.should == ['a','b']
    @set.get.should == ['a','b']

    @set << 'c'
    @set.member?('c').should be_true
    @set.include?('c').should be_true
    @set.member?('no').should be_false
    coll = @set.select{|st| st == 'c'}
    coll.should == ['c']
    @set.sort.should == ['a','b','c']
  end
  
  it "should handle set intersections, unions, and diffs" do
    @set_1 << 'a' << 'b' << 'c' << 'd' << 'e'
    @set_2 << 'c' << 'd' << 'e' << 'f' << 'g'
    @set_3 << 'a' << 'd' << 'g' << 'l' << 'm'
    @set_1.sort.should == %w(a b c d e)
    @set_2.sort.should == %w(c d e f g)
    @set_3.sort.should == %w(a d g l m)
    (@set_1 & @set_2).sort.should == ['c','d','e']
    @set_1.intersection(@set_2).sort.should == ['c','d','e']
    @set_1.intersection(@set_2, @set_3).sort.should == ['d']
    @set_1.intersect(@set_2).sort.should == ['c','d','e']
    @set_1.inter(@set_2, @set_3).sort.should == ['d']
    @set_1.interstore(INTERSTORE_KEY, @set_2).should == 3
    @set_1.redis.smembers(INTERSTORE_KEY).sort.should == ['c','d','e']
    @set_1.interstore(INTERSTORE_KEY, @set_2, @set_3).should == 1
    @set_1.redis.smembers(INTERSTORE_KEY).sort.should == ['d']

    (@set_1 | @set_2).sort.should == ['a','b','c','d','e','f','g']
    (@set_1 + @set_2).sort.should == ['a','b','c','d','e','f','g']
    @set_1.union(@set_2).sort.should == ['a','b','c','d','e','f','g']
    @set_1.union(@set_2, @set_3).sort.should == ['a','b','c','d','e','f','g','l','m']
    @set_1.unionstore(UNIONSTORE_KEY, @set_2).should == 7
    @set_1.redis.smembers(UNIONSTORE_KEY).sort.should == ['a','b','c','d','e','f','g']
    @set_1.unionstore(UNIONSTORE_KEY, @set_2, @set_3).should == 9
    @set_1.redis.smembers(UNIONSTORE_KEY).sort.should == ['a','b','c','d','e','f','g','l','m']

    (@set_1 ^ @set_2).sort.should == ["a", "b"]
    (@set_1 - @set_2).sort.should == ["a", "b"]
    (@set_2 - @set_1).sort.should == ["f", "g"]
    @set_1.difference(@set_2).sort.should == ["a", "b"]
    @set_1.diff(@set_2).sort.should == ["a", "b"]
    @set_1.difference(@set_2, @set_3).sort.should == ['b']
    @set_1.diffstore(DIFFSTORE_KEY, @set_2).should == 2
    @set_1.redis.smembers(DIFFSTORE_KEY).sort.should == ['a','b']
    @set_1.diffstore(DIFFSTORE_KEY, @set_2, @set_3).should == 1
    @set_1.redis.smembers(DIFFSTORE_KEY).sort.should == ['b']
  end

  it "should support renaming sets" do
    @set.should be_empty
    @set << 'a' << 'b' << 'a' << 3
    @set.sort.should == ['3','a','b']
    @set.key.should == 'spec/set'
    @set.rename('spec/set2').should be_true
    @set.key.should == 'spec/set2'
    old = Redis::Set.new('spec/set')
    old.should be_empty
    old << 'Tuff'
    @set.renamenx('spec/set').should be_false
    @set.renamenx(old).should be_false
    @set.renamenx('spec/foo').should be_true
    @set.clear
    @set.redis.del('spec/set2')
  end

  after :all do
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
  end
end

describe Redis::SortedSet do
  before :all do
    @set = Redis::SortedSet.new('spec/zset')
    @set_1 = Redis::SortedSet.new('spec/zset_1')
    @set_2 = Redis::SortedSet.new('spec/zset_2')
    @set_3 = Redis::SortedSet.new('spec/zset_3')
  end

  before :each do
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
  end

  it "should handle sets of simple values" do
    @set.should be_empty
    @set['a'] = 1
    @set['a'] = 2
    @set['a'] = 3
    @set['b'] = 5
    @set['c'] = 4
    @set[0,-1].should == ['a','c','b']
    @set.range(0,-1).should == ['a','c','b']
    @set.members.should == ['a','c','b']
    @set.members.should == ['a','c','b']
    @set.members(:withscores => true).should == ['a','3','c','4','b','5']
    @set.values(:withscores => true).should == ['a','3','c','4','b','5']
    @set['b'] = 5
    @set['b'] = 6
    @set.score('b').should == 6
    @set.delete('c')
    @set.to_s.should == 'a, b'
    @set.should == ['a','b']
    @set.members.should == ['a','b']
    @set['d'] = 0
    @set.rangebyscore(0,4).should == ['d','a']
    @set.rangebyscore(0,4, :count => 1).should == ['d']
    @set.rangebyscore(0,4, :count => 2).should == ['d','a']
    #@set.rangebyscore(0,4, :withscores => true).should == ['d','a']

    @set.delete('d')
    @set['c'] = 0
    @set.values.should == ['c','a','b']
    @set.length.should == 3
    @set.size.should == 3
  end

  # Not until Redis 1.3.5 with hashes
  xit "Redis 1.3.5: should handle set intersections, unions, and diffs" do
    @set_1['a'] = 5
    @set_2['b'] = 18
    @set_2['c'] = 12

    @set_2['a'] = 10
    @set_2['b'] = 15
    @set_2['c'] = 15

    (@set_1 & @set_2).sort.should == ['c','d','e']

    @set_1 << 'a' << 'b' << 'c' << 'd' << 'e'
    @set_2 << 'c' << 'd' << 'e' << 'f' << 'g'
    @set_3 << 'a' << 'd' << 'g' << 'l' << 'm'
    @set_1.sort.should == %w(a b c d e)
    @set_2.sort.should == %w(c d e f g)
    @set_3.sort.should == %w(a d g l m)
    (@set_1 & @set_2).sort.should == ['c','d','e']
    @set_1.intersection(@set_2).sort.should == ['c','d','e']
    @set_1.intersection(@set_2, @set_3).sort.should == ['d']
    @set_1.intersect(@set_2).sort.should == ['c','d','e']
    @set_1.inter(@set_2, @set_3).sort.should == ['d']
    @set_1.interstore(INTERSTORE_KEY, @set_2).should == 3
    @set_1.redis.smembers(INTERSTORE_KEY).sort.should == ['c','d','e']
    @set_1.interstore(INTERSTORE_KEY, @set_2, @set_3).should == 1
    @set_1.redis.smembers(INTERSTORE_KEY).sort.should == ['d']

    (@set_1 | @set_2).sort.should == ['a','b','c','d','e','f','g']
    (@set_1 + @set_2).sort.should == ['a','b','c','d','e','f','g']
    @set_1.union(@set_2).sort.should == ['a','b','c','d','e','f','g']
    @set_1.union(@set_2, @set_3).sort.should == ['a','b','c','d','e','f','g','l','m']
    @set_1.unionstore(UNIONSTORE_KEY, @set_2).should == 7
    @set_1.redis.smembers(UNIONSTORE_KEY).sort.should == ['a','b','c','d','e','f','g']
    @set_1.unionstore(UNIONSTORE_KEY, @set_2, @set_3).should == 9
    @set_1.redis.smembers(UNIONSTORE_KEY).sort.should == ['a','b','c','d','e','f','g','l','m']

    (@set_1 ^ @set_2).sort.should == ["a", "b"]
    (@set_1 - @set_2).sort.should == ["a", "b"]
    (@set_2 - @set_1).sort.should == ["f", "g"]
    @set_1.difference(@set_2).sort.should == ["a", "b"]
    @set_1.diff(@set_2).sort.should == ["a", "b"]
    @set_1.difference(@set_2, @set_3).sort.should == ['b']
    @set_1.diffstore(DIFFSTORE_KEY, @set_2).should == 2
    @set_1.redis.smembers(DIFFSTORE_KEY).sort.should == ['a','b']
    @set_1.diffstore(DIFFSTORE_KEY, @set_2, @set_3).should == 1
    @set_1.redis.smembers(DIFFSTORE_KEY).sort.should == ['b']
  end

  it "should support renaming sets" do
    @set.should be_empty
    # @set << 'a' << 'b' << 'a' << 3
    @set['zynga'] = 151
    @set['playfish'] = 202
    @set.members.should == ['zynga','playfish']
    @set.key.should == 'spec/zset'
    @set.rename('spec/zset2').should be_true
    @set.key.should == 'spec/zset2'
    old = Redis::SortedSet.new('spec/zset')
    old.should be_empty
    old['tuff'] = 54
    @set.renamenx('spec/zset').should be_false
    @set.renamenx(old).should be_false
    @set.renamenx('spec/zfoo').should be_true
    @set.clear
    @set.redis.del('spec/zset2')
  end

  after :all do
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
  end
end

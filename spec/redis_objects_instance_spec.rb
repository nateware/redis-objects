
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/counter'
require 'redis/list'
require 'redis/value'
require 'redis/lock'
require 'redis/set'
require 'redis/sorted_set'
require 'redis/hash_key'

describe Redis::Value do
  before do
    @value = Redis::Value.new('spec/value')
    @value.delete
  end

  it "should handle simple values" do
    @value.should == nil
    @value.value = 'Trevor Hoffman'
    @value.should == 'Trevor Hoffman'
    @value.get.should == 'Trevor Hoffman'
    @value.del.should == 1
    @value.should.be.nil
  end

  it "should handle complex marshaled values" do
    @value.options[:marshal] = true
    @value.should == nil
    @value.value = {:json => 'data'}
    @value.should == {:json => 'data'}
    
    # no marshaling
    @value.options[:marshal] = false
    v = {:json => 'data'}
    @value.value = v
    @value.should == v.to_s

    @value.options[:marshal] = true
    @value.value = [[1,2], {:t3 => 4}]
    @value.should == [[1,2], {:t3 => 4}]
    @value.get.should == [[1,2], {:t3 => 4}]
    @value.del.should == 1
    @value.should.be.nil
    @value.options[:marshal] = false
  end

  it "should support renaming values" do
    @value.value = 'Peter Pan'
    @value.key.should == 'spec/value'
    @value.rename('spec/value2')  # can't test result; switched from true to "OK"
    @value.key.should == 'spec/value2'
    @value.should == 'Peter Pan'
    old = Redis::Value.new('spec/value')
    old.should.be.nil
    old.value = 'Tuff'
    @value.renamenx('spec/value')  # can't test result; switched from true to "OK"
    @value.value.should == 'Peter Pan'
  end

  after do
    @value.delete
  end
end


describe Redis::List do
  describe "as a bounded list" do
    before do
      @list = Redis::List.new('spec/bounded_list',
                              $redis,
                              :maxlength => 10)
      1.upto(10) do |i|
        @list << i
      end

      # Make sure that adding < maxlength doesn't mess up.
      1.upto(10) do |i|
        @list.at(i - 1).should == i.to_s
      end
    end

    it "should push the first element out of the list" do
      @list << '11'
      @list.last.should == '11'
      @list.first.should == '2'
      @list.length.should == 10
    end

    it "should push the last element out of the list for unshift" do
      @list.unshift('0')
      @list.last.should == '9'
      @list.first.should == '0'
      @list.length.should == 10
    end

    after do
      @list.clear
    end
  end

  describe "with basic operations" do
    before do
      @list = Redis::List.new('spec/list')
      @list.clear
    end

    it "should handle lists of simple values" do
      @list.should.be.empty
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
      @list.include?('c').should.be.true
      @list.include?('no').should.be.false
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
      # Test against similar Ruby functionality
      a = @list.values
      @list[0..2].should == a[0..2]
      @list.slice(0..2).should == a.slice(0..2)
      @list[0, 2].should == a[0, 2]
      @list.range(0, 2).should == a[0..2]  # range for Redis works like .. in Ruby
      @list[0, 1].should == a[0, 1]
      @list.range(0, 1).should == a[0..1]  # range for Redis works like .. in Ruby
      @list[1, 3].should == a[1, 3]
      @list.slice(1, 3).should == a.slice(1, 3)
      @list[0, 0].should == []
      @list[0, -1].should == a[0, -1]
      @list.length.should == 4
      @list.size.should == 4
      @list.should == a
      @list.get.should == a

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
      @list.options[:marshal] = true
      v1 = {:json => 'data'}
      v2 = {:json2 => 'data2'}
      @list << v1
      @list << v2
      @list.first.should == v1
      @list.last.should == v2
      @list << [1,2,3,[4,5]]
      @list.last.should == [1,2,3,[4,5]]
      @list.shift.should == {:json => 'data'}
      @list.size.should == 2
      @list.delete(v2)
      @list.size.should == 1
      @list.options[:marshal] = false
    end
    
    it "should support renaming lists" do
      @list.should.be.empty
      @list << 'a' << 'b' << 'a' << 3
      @list.should == ['a','b','a','3']
      @list.key.should == 'spec/list'
      @list.rename('spec/list3', false)  # can't test result; switched from true to "OK"
      @list.key.should == 'spec/list'
      @list.redis.del('spec/list3')
      @list << 'a' << 'b' << 'a' << 3
      @list.rename('spec/list2')  # can't test result; switched from true to "OK"
      @list.key.should == 'spec/list2'
      @list.redis.lrange(@list.key, 0, 3).should == ['a','b','a','3']
      old = Redis::List.new('spec/list')
      old.should.be.empty
      old << 'Tuff'
      old.values.should == ['Tuff']
      @list.renamenx('spec/list').should.be.false
      @list.renamenx(old).should.be.false
      @list.renamenx('spec/foo').should.be.true
      old.values.should == ['Tuff']
      @list.clear
      @list.redis.del('spec/list2')
    end

    after do
      @list.clear
    end
  end
end

describe Redis::Counter do
  before do
    @counter  = Redis::Counter.new('spec/counter')
    @counter2 = Redis::Counter.new('spec/counter')
    @counter.reset
  end

  it "should support increment/decrement of counters" do
    @counter.key.should == 'spec/counter'
    @counter.incr(10)
    @counter.should == 10
    
    # math proxy ops
    (@counter == 10).should.be.true
    (@counter <= 10).should.be.true
    (@counter < 11).should.be.true
    (@counter > 9).should.be.true
    (@counter >= 10).should.be.true
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
    @counter.reset.should.be.true
    @counter.should == 0
    @counter.reset(15).should.be.true
    @counter.should == 15
  end

  after do
    @counter.delete
  end
end

describe Redis::Lock do
  before do
    $redis.flushall
  end

  it "should set the value to the expiration" do
    start = Time.now
    expiry = 15
    lock = Redis::Lock.new(:test_lock, :expiration => expiry)
    lock.lock do
      expiration = $redis.get("test_lock").to_f

      # The expiration stored in redis should be 15 seconds from when we started
      # or a little more
      expiration.should.be.close((start + expiry).to_f, 2.0)
    end

    # key should have been cleaned up
    $redis.get("test_lock").should.be.nil
  end

  it "should set value to 1 when no expiration is set" do
    lock = Redis::Lock.new(:test_lock)
    lock.lock do
      $redis.get('test_lock').should == '1'
    end

    # key should have been cleaned up
    $redis.get("test_lock").should.be.nil
  end

  it "should let lock be gettable when lock is expired" do
    expiry = 15
    lock = Redis::Lock.new(:test_lock, :expiration => expiry, :timeout => 0.1)

    # create a fake lock in the past
    $redis.set("test_lock", Time.now-(expiry + 60))

    gotit = false
    lock.lock do
      gotit = true
    end

    # should get the lock because it has expired
    gotit.should.be.true
    $redis.get("test_lock").should.be.nil
  end

  it "should not let non-expired locks be gettable" do
    expiry = 15
    lock = Redis::Lock.new(:test_lock, :expiration => expiry, :timeout => 0.1)

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

    error.should.be.kind_of(Redis::Lock::LockTimeout)

    # should not have the lock
    gotit.should.not.be.true

    # lock value should still be set
    $redis.get("test_lock").should.not.be.nil
  end

  it "should not remove the key if lock is held past expiration" do
    lock = Redis::Lock.new(:test_lock, :expiration => 0.0)

    lock.lock do
      sleep 1.1
    end

    # lock value should still be set since the lock was held for more than the expiry
    $redis.get("test_lock").should.not.be.nil
  end
end


describe Redis::HashKey do
  before do
    @hash  = Redis::HashKey.new('test_hash')
    @hash.clear
  end
  
  it "should handle complex marshaled values" do
    @hash.options[:marshal] = true
    @hash['abc'].should == nil
    @hash['abc'] = {:json => 'data'}
    @hash['abc'].should == {:json => 'data'}
    
    # no marshaling
    @hash.options[:marshal] = false
    v = {:json => 'data'}
    @hash['abc'] = v
    @hash['abc'].should == v.to_s

    @hash.options[:marshal] = true
    @hash['abc'] = [[1,2], {:t3 => 4}]
    @hash['abc'].should == [[1,2], {:t3 => 4}]
    @hash.fetch('abc').should == [[1,2], {:t3 => 4}]
    @hash.delete('abc').should == 1
    @hash.fetch('abc').should.be.nil
    
    @hash.options[:marshal] = true
    @hash.bulk_set('abc' => [[1,2], {:t3 => 4}], 'def' => [[6,8], {:t4 => 8}])
    hsh = @hash.bulk_get('abc', 'def', 'foo')
    hsh['abc'].should == [[1,2], {:t3 => 4}]
    hsh['def'].should == [[6,8], {:t4 => 8}]
    hsh['foo'].should.be.nil
    
    hsh = @hash.all
    hsh['abc'].should == [[1,2], {:t3 => 4}]
    hsh['def'].should == [[6,8], {:t4 => 8}]
    
    @hash.values.should == [[[1,2], {:t3 => 4}], [[6,8], {:t4 => 8}]]
    
    @hash.delete('def').should == 1
    @hash.delete('abc').should == 1
    
    @hash.options[:marshal] = false
  end
  
  it "should get and set values" do
    @hash['foo'] = 'bar'
    @hash['foo'].should == 'bar'
  end

  it "should know what exists" do
    @hash['foo'] = 'bar'
    @hash.include?('foo').should == true
  end

  it "should delete values" do
    @hash['abc'] = 'xyz'
    @hash.delete('abc')
    @hash['abc'].should == nil
  end

  it "should respond to each" do
    @hash['foo'] = 'bar'
    @hash.each do |key, val|
      key.should == 'foo'
      val.should == 'bar'
    end
  end
  
  it "should have 1 item" do
    @hash['foo'] = 'bar'
    @hash.size.should == 1
  end

  it "should respond to each_key" do
    @hash['foo'] = 'bar'
    @hash.each_key do |key|
      key.should == 'foo'
    end
  end

  it "should respond to each_value" do
    @hash['foo'] = 'bar'
    @hash.each_value do |val|
      val.should == 'bar'
    end
  end

  it "should respond to empty?" do
    @empty = Redis::HashKey.new('test_empty_hash')
    @empty.respond_to?(:empty?).should == true
  end

  it "should be empty after a clear" do
    @hash['foo'] = 'bar'
    @hash.all.should == {'foo' => 'bar'}
    @hash.clear
    @hash.should.be.empty
  end
  
  it "should respond to bulk_set" do
    @hash.bulk_set({'abc' => 'xyz', 'bizz' => 'bazz'})
    @hash['abc'].should == 'xyz'
    @hash['bizz'].should == 'bazz'

    @hash.bulk_set('abc' => '123', 'bang' => 'michael')
    @hash['abc'].should == '123'
    @hash['bang'].should == 'michael'

    @hash.bulk_set(:sym1 => 'val1', :sym2 => 'val2')
    @hash['sym1'].should == 'val1'
    @hash['sym2'].should == 'val2'
  end

  it "should respond to bulk_get" do
    @hash['foo'] = 'bar'
    hsh = @hash.bulk_get('abc','foo')
    hsh['abc'].should == nil
    hsh['foo'].should == 'bar'
  end

  it "should increment field" do
    @hash.incr('counter')
    @hash.incr('counter')
    @hash['counter'].to_i.should == 2
  end
  

  after do
    @hash.clear
  end
  
end

describe Redis::Set do
  before do
    @set = Redis::Set.new('spec/set')
    @set_1 = Redis::Set.new('spec/set_1')
    @set_2 = Redis::Set.new('spec/set_2')
    @set_3 = Redis::Set.new('spec/set_3')
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
  end

  it "should handle sets of simple values" do
    @set.should.be.empty
    @set << 'a' << 'a' << 'a'
    @set.should == ['a']
    @set.get.should == ['a']
    @set << 'b' << 'b'
    @set.to_s.should == 'a, b'
    @set.should == ['a','b']
    @set.members.should == ['a','b']
    @set.members.reverse.should == ['b','a']  # common question
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
    @set.member?('c').should.be.true
    @set.include?('c').should.be.true
    @set.member?('no').should.be.false
    coll = @set.select{|st| st == 'c'}
    coll.should == ['c']
    @set.sort.should == ['a','b','c']
    @set.delete_if{|m| m == 'c'}
    @set.sort.should == ['a','b']
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
    @set.should.be.empty
    @set << 'a' << 'b' << 'a' << 3
    @set.sort.should == ['3','a','b']
    @set.key.should == 'spec/set'
    @set.rename('spec/set2')  # can't test result; switched from true to "OK"
    @set.key.should == 'spec/set2'
    old = Redis::Set.new('spec/set')
    old.should.be.empty
    old << 'Tuff'
    @set.renamenx('spec/set').should.be.false
    @set.renamenx(old).should.be.false
    @set.renamenx('spec/foo').should.be.true
    @set.clear
    @set.redis.del('spec/set2')
  end

  after do
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
  end
end

describe Redis::SortedSet do
  before do
    @set = Redis::SortedSet.new('spec/zset')
    @set_1 = Redis::SortedSet.new('spec/zset_1')
    @set_2 = Redis::SortedSet.new('spec/zset_2')
    @set_3 = Redis::SortedSet.new('spec/zset_3')
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
  end

  it "should handle sets of simple values" do
    @set.should.be.empty
    @set['a'] = 11
    @set['a'] = 21
    @set.add('a', 5)
    @set.score('a').should == 5
    @set['a'].should == 5
    @set['a'] = 3
    @set['b'] = 5.6
    @set['b'].should == 5.6
    @set['c'] = 4

    a = @set.members
    @set[0,-1].should == a[0,-1]
    @set[0..2].should == a[0..2]
    @set.slice(0..2).should == a.slice(0..2)
    @set[0, 2].should == a[0,2]
    @set.slice(0, 2).should == a.slice(0, 2)
    @set.range(0, 2).should == a[0..2]
    @set[0, 0].should == []
    @set.range(0,1,:withscores => true).should == [['a',3],['c',4]]
    @set.range(0,-1).should == a[0..-1]
    @set.revrange(0,-1).should == a[0..-1].reverse
    @set[0..1].should == a[0..1]
    @set[1].should == 0  # missing
    @set.at(1).should == 'c'
    @set.first.should == 'a'
    @set.last.should == 'b'

    @set.members.should == ['a','c','b']
    @set.members.reverse.should == ['b','c','a']
    @set.members(:withscores => true).should == [['a',3],['c',4],['b',5.6]]
    @set.members(:with_scores => true).should == [['a',3],['c',4],['b',5.6]]
    @set.members(:withscores => true).reverse.should == [['b',5.6],['c',4],['a',3]]

    @set['b'] = 5
    @set['b'] = 6
    @set.score('b').should == 6
    @set.delete('c')
    @set.to_s.should == 'a, b'
    @set.should == ['a','b']
    @set.members.should == ['a','b']
    @set['d'] = 0
    
    @set.rangebyscore(0, 4).should == ['d','a']
    @set.rangebyscore(0, 4, :count => 1).should == ['d']
    @set.rangebyscore(0, 4, :count => 2).should == ['d','a']
    @set.rangebyscore(0, 4, :limit => 2).should == ['d','a']

    # Redis 1.3.5
    # @set.rangebyscore(0,4, :withscores => true).should == [['d',4],['a',3]]
    # @set.revrangebyscore(0,4).should == ['d','a']
    # @set.revrangebyscore(0,4, :count => 2).should == ['a','d']
    # @set.rank('b').should == 2
    # @set.revrank('b').should == 3

    @set['f'] = 100
    @set['g'] = 110
    @set['h'] = 120
    @set['j'] = 130
    @set.incr('h', 20)
    @set.remrangebyscore(100, 120)
    @set.members.should == ['d','a','b','j','h']

    # Redis 1.3.5
    # @set['h'] = 12
    # @set['j'] = 13
    # @set.remrangebyrank(4,-1)
    # @set.members.should == ['d','a','b']

    @set.delete('d')
    @set['c'] = 200
    @set.members.should == ['a','b','j','h','c']
    @set.delete('c')
    @set.length.should == 4
    @set.size.should == 4
    
    @set.delete_if{|m| m == 'b'}
    @set.size.should == 3
  end

  it "should support renaming sets" do
    @set.should.be.empty
    @set['zynga'] = 151
    @set['playfish'] = 202
    @set.members.should == ['zynga','playfish']
    @set.key.should == 'spec/zset'
    @set.rename('spec/zset2')  # can't test result; switched from true to "OK"
    @set.key.should == 'spec/zset2'
    old = Redis::SortedSet.new('spec/zset')
    old.should.be.empty
    old['tuff'] = 54
    @set.renamenx('spec/zset').should.be.false
    @set.renamenx(old).should.be.false
    @set.renamenx('spec/zfoo').should.be.true
    @set.clear
    @set.redis.del('spec/zset2')
  end

  after do
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
  end
end

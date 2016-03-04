
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'

describe Redis::Value do
  before do
    @value = Redis::Value.new('spec/value')
    @value.delete
  end

  it "should marshal default value" do
    @value = Redis::Value.new('spec/value', :default => {:json => 'data'}, :marshal => true)
    @value.value.should == {:json => 'data'}
  end

  it "should be able to set the default value to false" do
    @value = Redis::Value.new('spec/value', :default => false, :marshal => true)
    @value.value.should == false
  end

  it "should handle simple values" do
    @value.should == nil
    @value.value = 'Trevor Hoffman'
    @value.should == 'Trevor Hoffman'
    @value.get.should == 'Trevor Hoffman'
    @value.del.should == 1
    @value.should.be.nil
    @value.value = 42
    @value.value.should == '42'
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

  it "should not erroneously unmarshall a string" do
    json_string = {json: 'value'}
    @value = Redis::Value.new('spec/value', :marshal => true)
    @value.value = json_string
    @value.value.should == json_string
    @value.clear

    default_json_string = {json: 'default'}
    @value = Redis::Value.new('spec/default', :default => default_json_string, :marshal => true)
    @value.value.should == default_json_string
    @value.clear

    marshalled_string = Marshal.dump({json: 'marshal'})
    @value = Redis::Value.new('spec/marshal', :default => marshalled_string, :marshal => true)
    @value.value.should == marshalled_string
    @value.clear
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

  it "should provide a readable inspect" do
    @value.value = 'monkey'
    @value.inspect.should == '#<Redis::Value "monkey">'
    @value.value = 1234
    @value.inspect.should == '#<Redis::Value "1234">'
  end

  it 'should delegate unrecognized methods to the value' do
    @value.value = 'monkey'
    @value.to_sym.should == :monkey
  end

  it 'should properly pass equality operations on to the value' do
    @value.value = 'monkey'
    @value.should == 'monkey'
  end

  it 'should properly pass nil? on to the value' do
    @value.delete
    @value.nil?.should == true
  end

  it 'should equate setting the value to nil to deletion' do
    @value.value = nil
    @value.nil?.should == true
  end

  describe "with expiration" do
    [:value=, :set].each do |meth|
      it "#{meth} should set time to live in seconds when expiration option assigned" do
        @value = Redis::Value.new('spec/value', :expiration => 10)
        @value.send(meth, 'monkey')
        @value.ttl.should > 0
        @value.ttl.should <= 10
      end

      it "#{meth} should set expiration when expireat option assigned" do
        @value = Redis::Value.new('spec/value', :expireat => Time.now + 10.seconds)
        @value.send(meth, 'monkey')
        @value.ttl.should > 0
      end
    end
  end

  after do
    @value.delete
  end
end

describe Redis::List do
  describe "as a bounded list" do
    before do
      @list = Redis::List.new('spec/bounded_list',
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

  describe "basic operations" do
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
      @list.push 'h'
      @list.push 'i', 'j'
      @list.should == ['a','c','f','j','h','i','j']
      # Test against similar Ruby functionality
      a = @list.values
      @list[0..2].should == a[0..2]
      @list[0...2].should == a[0...2]
      @list.slice(0..2).should == a.slice(0..2)
      @list[0, 2].should == a[0, 2]
      @list.range(0, 2).should == a[0..2]  # range for Redis works like .. in Ruby
      @list[0, 1].should == a[0, 1]
      @list.range(0, 1).should == a[0..1]  # range for Redis works like .. in Ruby
      @list[1, 3].should == a[1, 3]
      @list.slice(1, 3).should == a.slice(1, 3)
      @list[0, 0].should == []
      @list[0, -1].should == a[0, -1]
      @list.length.should == 7
      @list.should == a
      @list.get.should == a
      @list.pop # lose 'j'
      @list.size.should == 6

      i = -1
      @list.each do |st|
        st.should == @list[i += 1]
      end
      @list.should == ['a','c','f','j','h','i']
      @list.get.should == ['a','c','f','j','h','i']

      @list.each_with_index do |st,i|
        st.should == @list[i]
      end
      @list.should == ['a','c','f','j','h','i']
      @list.get.should == ['a','c','f','j','h','i']

      coll = @list.collect{|st| st}
      coll.should == ['a','c','f','j','h','i']
      @list.should == ['a','c','f','j','h','i']
      @list.get.should == ['a','c','f','j','h','i']

      @list << 'a'
      coll = @list.select{|st| st == 'a'}
      coll.should == ['a','a']
      @list.should == ['a','c','f','j','h','i','a']
      @list.get.should == ['a','c','f','j','h','i','a']
    end

    it "should support popping & shifting multiple values" do
      @list.should.be.empty

      @list << 'a' << 'b' << 'c'
      @list.shift(2).should == ['a', 'b']
      @list.shift(2).should == ['c']
      @list.shift(2).should == []

      @list << 'a' << 'b' << 'c'
      @list.pop(2).should == ['b', 'c']
      @list.pop(2).should == ['a']
      @list.pop(2).should == []
    end

    it "should handle rpoplpush" do
      list2 = Redis::List.new("spec/list2")
      list2.clear

      @list << "a" << "b"
      result = @list.rpoplpush(list2)
      result.should == "b"
      @list.should == ["a"]
      list2.should == ["b"]
    end

    it "should handle insert" do
      @list << 'b' << 'd'
      @list.insert(:before,'b','a')
      @list.insert(:after,'b','c')
      @list.insert("before",'a','z')
      @list.insert("after",'d','e')
      @list.should == ['z','a','b','c','d','e']
    end

    it "should handle insert at a specific index" do
      @list << 'b' << 'd'
      @list.should == ['b','d']
      @list[0] = 'a'
      @list.should == ['a', 'd']
      @list[1] = 'b'
      @list.should == ['a', 'b']
    end

    it "should handle lists of complex data types" do
      @list.options[:marshal] = true
      v1 = {:json => 'data'}
      v2 = {:json2 => 'data2'}
      v3 = [1,2,3]
      @list << v1
      @list << v2
      @list.first.should == v1
      @list[0] = @list[0].tap{|d| d[:json] = 'data_4'}
      @list.first.should == {:json => 'data_4'}
      @list.last.should == v2
      @list << [1,2,3,[4,5],6]
      @list.last.should == [1,2,3,[4,5],6]
      @list.shift.should == {:json => 'data_4'}
      @list.size.should == 2
      @list.delete(v2)
      @list.size.should == 1
      @list.push v1, v2
      @list[1].should == v1
      @list.last.should == v2
      @list.size.should == 3
      @list.unshift v2, v3
      @list.size.should == 5
      @list.first.should == v3
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

    it "responds to #value" do
      @list << 'a'
      @list.value.should == @list.get
      @list.value.should == ['a']
    end

    it "should support to_json" do
      @list << 'a'
      JSON.parse(@list.to_json)['value'].should == ['a']
    end

    it "should support as_json" do
      @list << 'a'
      @list.as_json['value'].should == ['a']
    end

    after do
      @list.clear
    end
  end

  describe 'with expiration' do
    [:push, :<<, :unshift].each do |meth, args|
      it "#{meth} expiration: option" do
        @list = Redis::List.new('spec/list_exp', :expiration => 10)
        @list.clear
        @list.send(meth, 'val')
        @list.ttl.should > 0
        @list.ttl.should <= 10
      end

      it "#{meth} expireat: option" do
        @list = Redis::List.new('spec/list_exp', :expireat => Time.now + 10.seconds)
        @list.clear
        @list.send(meth, 'val')
        @list.ttl.should > 0
        @list.ttl.should <= 10
      end
    end

    it "[]= expiration: option" do
      @list = Redis::List.new('spec/list_exp', :expiration => 10)
      @list.clear
      @list.redis.rpush(@list.key, 'hello')
      @list[0] = 'world'
      @list.ttl.should > 0
      @list.ttl.should <= 10
    end

    it "[]= expireat: option" do
      @list = Redis::List.new('spec/list_exp', :expireat => Time.now + 10.seconds)
      @list.clear
      @list.redis.rpush(@list.key, 'hello')
      @list[0] = 'world'
      @list.ttl.should > 0
      @list.ttl.should <= 10
    end

    it "insert expiration: option" do
      @list = Redis::List.new('spec/list_exp', :expiration => 10)
      @list.clear
      @list.redis.rpush(@list.key, 'hello')
      @list.insert 'BEFORE', 'hello', 'world'
      @list.ttl.should > 0
      @list.ttl.should <= 10
    end

    it "insert expireat: option" do
      @list = Redis::List.new('spec/list_exp', :expireat => Time.now + 10.seconds)
      @list.clear
      @list.redis.rpush(@list.key, 'hello')
      @list.insert 'BEFORE', 'hello', 'world'
      @list.ttl.should > 0
      @list.ttl.should <= 10
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
    @counter.getset(111).should == 15
    @counter.should == 111
  end

  it "should support increment/decrement by float" do
    @counter = Redis::Counter.new('spec/floater')
    @counter.set 10.5
    @counter.incrbyfloat 1
    @counter.incrbyfloat 0.01
    @counter.to_f.should == 11.51
    @counter.set '5.0e3'
    @counter.decrbyfloat -14.31
    @counter.incrbyfloat 2.0e2
    @counter.to_f.should == 5214.31
    @counter.clear
  end

  it "should support an atomic block" do
    @counter = Redis::Counter.new("spec/block_counter")
    @counter.should == 0
    @counter.increment(1)
    # The block is never executed.
    @updated =
      @counter.increment(1) do |updated|
        if updated == 2
          'yep'
        else
          raise("test failed")
        end
      end
    @updated.should == 'yep'
    @counter.should == 2
  end

  it "should support #to_json" do
    @counter.increment
    JSON.parse(@counter.to_json)['value'].should == 1
  end

  it "should support #as_json" do
    @counter.increment
    @counter.as_json['value'].should == 1
  end

  describe 'with expiration' do
    it 'should set time to live in seconds' do
      @counter = Redis::Counter.new('spec/counter', :expiration => 10)
      @counter.increment
      @counter.ttl.should > 0
      @counter.ttl.should <= 10
    end

   [:increment, :incr, :incrby, :incrbyfloat,
    :decrement, :decr, :decrby, :decrbyfloat, :reset].each do |meth|
      describe meth do
        it "expiration: option" do
          @counter = Redis::Counter.new('spec/counter_exp', :expiration => 10)
          @counter.send(meth)
          @counter.ttl.should > 0
          @counter.ttl.should <= 10
        end
        it "expireat: option" do
          @counter = Redis::Counter.new('spec/counter_exp', :expireat => Time.now + 10.seconds)
          @counter.send(meth)
          @counter.ttl.should > 0
          @counter.ttl.should <= 10
        end
        after do
          @counter.reset
        end
      end
    end

   [:set, :value=].each do |meth|
      describe meth do
        it "expiration: option" do
          @counter = Redis::Counter.new('spec/counter_exp', :expireat => Time.now + 10.seconds)
          @counter.send(meth, 99)
          @counter.should == 99
          @counter.ttl.should > 0
          @counter.ttl.should <= 10
        end
        it "expireat: option" do
          @counter = Redis::Counter.new('spec/counter_exp', :expireat => Time.now + 10.seconds)
          @counter.send(meth, 99)
          @counter.should == 99
          @counter.ttl.should > 0
          @counter.ttl.should <= 10
        end
        after do
          @counter.reset
        end
      end
    end
  end

  after do
    @counter.delete
  end
end

describe Redis::Lock do
  before do
    REDIS_HANDLE.flushall
  end

  it "should set the value to the expiration" do
    start = Time.now
    expiry = 15
    lock = Redis::Lock.new(:test_lock, :expiration => expiry)
    lock.lock do
      expiration = REDIS_HANDLE.get("test_lock").to_f

      # The expiration stored in redis should be 15 seconds from when we started
      # or a little more
      expiration.should.be.close((start + expiry).to_f, 2.0)
    end

    # key should have been cleaned up
    REDIS_HANDLE.get("test_lock").should.be.nil
  end

  it "should set value to 1 when no expiration is set" do
    lock = Redis::Lock.new(:test_lock)
    lock.lock do
      REDIS_HANDLE.get('test_lock').should == '1'
    end

    # key should have been cleaned up
    REDIS_HANDLE.get("test_lock").should.be.nil
  end

  it "should let lock be gettable when lock is expired" do
    expiry = 15
    lock = Redis::Lock.new(:test_lock, :expiration => expiry, :timeout => 0.1)

    # create a fake lock in the past
    REDIS_HANDLE.set("test_lock", Time.now-(expiry + 60))

    gotit = false
    lock.lock do
      gotit = true
    end

    # should get the lock because it has expired
    gotit.should.be.true
    REDIS_HANDLE.get("test_lock").should.be.nil
  end

  it "should not let non-expired locks be gettable" do
    expiry = 15
    lock = Redis::Lock.new(:test_lock, :expiration => expiry, :timeout => 0.1)

    # create a fake lock
    REDIS_HANDLE.set("test_lock", (Time.now + expiry).to_f)

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
    REDIS_HANDLE.get("test_lock").should.not.be.nil
  end

  it "should not remove the key if lock is held past expiration" do
    lock = Redis::Lock.new(:test_lock, :expiration => 0.0)

    lock.lock do
      sleep 1.1
    end

    # lock value should still be set since the lock was held for more than the expiry
    REDIS_HANDLE.get("test_lock").should.not.be.nil
  end

  it "should respond to #to_json" do
    Redis::Lock.new(:test_lock).to_json.should.be.kind_of(String)
  end

  it "should respond to #as_json" do
    Redis::Lock.new(:test_lock).as_json.should.be.kind_of(Hash)
  end
end

describe Redis::HashKey do
  describe "With Marshal" do
    before do
      @hash = Redis::HashKey.new('test_hash', {:marshal_keys=>{'created_at'=>true}})
      @hash.clear
    end

    it "should marshal specified keys" do
      @hash['created_at'] = Time.now
      @hash['created_at'].class.should == Time
    end

    it "should not marshal unless required" do
      @hash['updated_at'] = Time.now
      @hash['updated_at'].class.should == String
    end

    it "should marshall appropriate key with bulk set and get" do
      @hash.bulk_set({'created_at'=>Time.now, 'updated_at'=>Time.now})

      @hash['created_at'].class.should == Time
      @hash['updated_at'].class.should == String

      h = @hash.bulk_get('created_at', 'updated_at')
      h['created_at'].class.should == Time
      h['updated_at'].class.should == String

      h = @hash.all
      h['created_at'].class.should == Time
      h['updated_at'].class.should == String
    end
  end

  before do
    @hash = Redis::HashKey.new('test_hash')
    @hash.clear
  end

  it "should handle complex marshaled values" do
    @hash.options[:marshal] = true
    @hash['abc'].should == nil
    @hash['abc'] = {:json => 'hash marshal'}
    @hash['abc'].should == {:json => 'hash marshal'}

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

    @hash.values.sort.should == [[[1,2], {:t3 => 4}], [[6,8], {:t4 => 8}]].sort

    @hash.delete('def').should == 1
    @hash.delete('abc').should == 1

    @hash.options[:marshal] = false
  end

  it "should marshal nil correctly" do
    @hash.options[:marshal] = true

    @hash['test'].should.be.nil
    @hash['test'] = nil
    @hash['test'].should.be.nil
    @hash.delete('test').should == 1
    @hash['test'].should.be.nil

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

  it "should handle increment/decrement" do
    @hash['integer'] = 1
    @hash.incrby('integer')
    @hash.incrby('integer', 2)
    @hash.get('integer').to_i.should == 4

    @hash['integer'] = 9
    @hash.decrby('integer')
    @hash.decrby('integer', 6)
    @hash.get('integer').to_i.should == 2

    @hash['float'] = 12.34
    @hash.decrbyfloat('float')
    @hash.decrbyfloat('float', 6.3)
    @hash.get('float').to_f.should == 5.04

    @hash['float'] = '5.0e3'
    @hash.incrbyfloat('float')
    @hash.incrbyfloat('float', '1.23e3')
    @hash.incrbyfloat('float', 45.3).should == 6276.3
    @hash.get('float').to_f.should == 6276.3
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

  it "should respond to fill" do
    @hash['foo'] = 'bar'

    @hash.fill('abc' => '123', 'bang' => 'michael')
    @hash['foo'].should == 'bar'
    @hash['abc'].should == '123'
    @hash['bang'].should == 'michael'
    @hash.keys.sort.should == ['abc', 'bang', 'foo']
  end

  it "raises an error if a non-Hash is passed to fill" do
    lambda { @hash.fill([]) }.should.raise(ArgumentError)
  end

  it "should fetch default values" do
    @hash['abc'] = "123"

    value = @hash.fetch('missing_key','default_value')
    block = @hash.fetch("missing_key") {|key| "oops: #{key}" }
    no_error = @hash.fetch("abc") rescue "error"

    no_error.should == "123"
    value.should == "default_value"
    block.should == "oops: missing_key"
  end

  it "should respond to #value" do
    @hash['abc'] = "123"
    @hash.value.should == @hash.all
    @hash.value.should == { "abc" => "123" }
  end

  it "should respond to #to_json" do
    @hash['abc'] = "123"
    JSON.parse(@hash.to_json)['value'].should == { "abc" => "123" }
  end

  it "should respond to #as_json" do
    @hash['abc'] = "123"
    @hash.as_json['value'].should == { "abc" => "123" }
  end

  describe 'with expiration' do
    {
      :incrby      => 'somekey',
      :incr        => 'somekey',
      :incrbyfloat => 'somekey',
      :decrby      => 'somekey',
      :decr        => 'somekey',
      :decrbyfloat => 'somekey',
      :store       => ['somekey', 'somevalue'],
      :[]=         => ['somekey', 'somevalue'],
      :bulk_set    => [{ 'somekey' => 'somevalue' }],
      :update      => [{ 'somekey' => 'somevalue' }],
      :fill        => [{ 'somekey' => 'somevalue' }]
    }.each do |meth, args|
      it "#{meth} expiration: option" do
        @hash = Redis::HashKey.new('spec/hash_expiration', :expiration => 10)
        @hash.clear
        @hash.send(meth, *args)
        @hash.ttl.should > 0
        @hash.ttl.should <= 10
      end

      it "#{meth} expireat: option" do
        @hash = Redis::HashKey.new('spec/hash_expireat', :expireat => Time.now + 10.seconds)
        @hash.clear
        @hash.send(meth, *args)
        @hash.ttl.should > 0
        @hash.ttl.should <= 10
      end
    end
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
    @set.to_s.should == 'a'
    @set.get.should == ['a']
    @set << 'b' << 'b'
    @set.sort.should == ['a','b']
    @set.members.sort.should == ['a','b']
    @set.members.sort.reverse.should == ['b','a']  # common question
    @set.get.sort.should == ['a','b']
    @set << 'c'
    @set.sort.should == ['a','b','c']
    @set.get.sort.should == ['a','b','c']
    @set.delete('c')
    @set.sort.should == ['a','b']
    @set.get.sort.should == ['a','b']
    @set.length.should == 2
    @set.size.should == 2
    @set.delete('a')
    @set.pop.should == 'b'

    @set.add('a')
    @set.add('b')

    i = 0
    @set.each do |st|
      i += 1
    end
    i.should == @set.length

    coll = @set.sort.collect{|st| st}
    coll.should == ['a','b']
    @set.sort.should == ['a','b']
    @set.get.sort.should == ['a','b']

    @set << 'c'
    @set.member?('c').should.be.true
    @set.include?('c').should.be.true
    @set.member?('no').should.be.false
    coll = @set.select{|st| st == 'c'}
    coll.should == ['c']
    @set.sort.should == ['a','b','c']
    @set.delete_if{|m| m == 'c'}
    @set.sort.should == ['a','b']

    @set << nil
    @set.include?("").should.be.true
  end

  it "should handle empty array adds" do
    should.not.raise(Redis::CommandError) { @set.add([]) }
    @set.should.be.empty

    should.not.raise(Redis::CommandError) { @set << [] }
    @set.should.be.empty
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

  it "should handle variadic sadd operations" do
     @set.should.be.empty
     @set << 'a'
     @set.merge('b', 'c')
     @set.members.sort.should == ['a', 'b', 'c']
     @set.merge(['d','c','e'])
     @set.members.sort.should == ['a', 'b', 'c', 'd', 'e']
  end

  it "should support sorting" do
    @set_1 << 'c' << 'b' << 'a' << 'e' << 'd'
    @set_1.sort.should == %w(a b c d e)
    @set_1.sort(SORT_ORDER).should == %w(e d c b a)

    @set_2 << 2 << 4 << 3 << 1 << 5
    @set_2.sort.should == %w(1 2 3 4 5)
    @set_2.sort(SORT_LIMIT).should == %w(3 4)

    @set_3 << 'm_4' << 'm_5' << 'm_1' << 'm_3' << 'm_2'
    ### incorrect interpretation of what the :by parameter means
    ### :by will look up values of keys so it would try to find a value in
    ### redis of "m_m_1" which doesn't exist at this point, it is not a way to
    ### alter the value to sort by but rather use a different value for this value
    ### in the set (Kris Fox)
    # @set_3.sort(:by => 'm_*').should == %w(m_1 m_2 m_3 m_4 m_5)
    # below passes just fine
    @set_3.sort.should == %w(m_1 m_2 m_3 m_4 m_5)

    val1 = Redis::Value.new('spec/3/sorted')
    val2 = Redis::Value.new('spec/4/sorted')

    val1.set('val3')
    val2.set('val4')

    @set_2.sort(SORT_GET).should == ['val3', 'val4']
    @set_2.sort(SORT_STORE).should == 2
    @set_2.redis.type(SORT_STORE[:store]).should == 'list'
    @set_2.redis.lrange(SORT_STORE[:store], 0, -1).should == ['val3', 'val4']

    @set_1.redis.del val1.key
    @set_1.redis.del val2.key
    @set_1.redis.del SORT_STORE[:store]
  end

  it "should respond to #value" do
    @set_1 << 'a'
    @set_1.value.should == @set_1.members
    @set_1.value.should == ['a']
  end

  it "should respond to #to_json" do
    @set_1 << 'a'
    JSON.parse(@set_1.to_json)['value'].should == ['a']
  end

  it "should respond to #as_json" do
    @set_1 << 'a'
    @set_1.as_json['value'].should == ['a']
  end

  describe "with expiration" do
    [:<<, :add, :merge].each do |meth|
      it "should set time to live in seconds when expiration option assigned" do
        @set = Redis::Set.new('spec/set', :expiration => 10)
        @set.send(meth, 'val')
        @set.ttl.should > 0
        @set.ttl.should <= 10
      end

      it "should set expiration when expireat option assigned" do
        @set = Redis::Set.new('spec/set', :expireat => Time.now + 10.seconds)
        @set.send(meth, 'val')
        @set.ttl.should > 0
        @set.ttl.should <= 10
      end
    end
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
    @set_4 = Redis::SortedSet.new('spec/zset_3', :marshal => true)
    @set_5 = Redis::Set.new('spec/zset_4')
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
    @set_4.clear
    @set_5.clear
  end

  it "should handle sorted sets of simple values" do
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
    @set[0...2].should == a[0...2]
    @set.slice(0..2).should == a.slice(0..2)
    @set[0, 2].should == a[0,2]
    @set.slice(0, 2).should == a.slice(0, 2)
    @set.range(0, 2).should == a[0..2]
    @set[0, 0].should == []
    @set.range(0,1,:withscores => true).should == [['a',3],['c',4]]
    @set.revrange(0,1,:withscores => true).should == [['b',5.6],['c',4]]
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
    @set.members(:withscores => true).should == @set.range(0,-1,:withscores => true)
    @set.members(:withscores => true).reverse.should == @set.revrange(0,-1,:withscores => true)

    @set['b'] = 5
    @set['b'] = 6
    @set.score('b').should == 6
    @set.score('f').should == nil
    @set.delete('c')
    @set.to_s.should == 'a, b'
    @set.should == ['a','b']
    @set.members.should == ['a','b']
    @set['d'] = 0

    @set.rangebyscore(0, 4).should == ['d','a']
    @set.rangebyscore(0, 4, :count => 1).should == ['d']
    @set.rangebyscore(0, 4, :count => 2).should == ['d','a']
    @set.rangebyscore(0, 4, :limit => 2).should == ['d','a']

    @set.revrangebyscore(4, 0, :withscores => true).should == [['a', 3], ['d', 0]]
    @set.revrangebyscore(4, 0).should == ['a', 'd']
    @set.revrangebyscore(4, 0, :count => 2).should == ['a','d']
    @set.rank('b').should == 2
    @set.revrank('b').should == 0

    # shouldn't report a rank for a key that doesn't exist
    @set.rank('foo').should.not == @set.rank(@set.first)
    @set.rank('foo').should == nil

    # shouldn't report a rank for a key that doesn't exist
    @set.revrank('foo').should.not == @set.revrank(@set.first)
    @set.revrank('foo').should == nil

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

    @set.range_size(100, 120).should == 0
    @set.range_size(0, 100).should == 2
    @set.range_size('-inf', 'inf').should == 4

    @set.delete_if{|m| m == 'b'}
    @set.size.should == 3
  end

  it "should handle inserting multiple values at once" do
    @set.merge({ 'a' => 1, 'b' => 2 })
    @set.merge([['a', 4], ['c', 5]])
    @set.merge({d: 0, e: 9 })

    @set.members.should == ["d", "b", "a", "c", "e"]

    @set[:f] = 3
    @set.members.should == ["d", "b", "f", "a", "c", "e"]
  end

  it "should support marshaling key names" do
    @set_4.members.should == []

    @set_4[Object] = 1.20
    @set_4[Module] = 2.30
    @set_4[nil] = 3.40

    @set_4.incr(Object, 0.5)
    @set_4.decr(Module, 0.5)
    @set_4.incr(nil, 0.5)

    @set_4[Object].round(1).should == 1.7
    @set_4[Module].round(1).should == 1.8
    @set_4[nil].round(1).should == 3.9

    @set_4.members.should == [Object, Module, nil]
  end

  it "should support renaming sorted sets" do
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

  it "should handle unions" do
    @set_1.add('a', 1)
    @set_1.add('b', 4)
    @set_1.add('c', 3)

    @set_2.add('b', 2)
    @set_2.add('c', 1)
    @set_2.add('d', 0)

    @set_1.unionstore(@set.key, @set_2)
    # @set is now: [[d, 0], [a, 1], [c, 4], [b, 6]]
    @set.members.should == ['d', 'a', 'c', 'b']

    @set_2.unionstore(@set, @set_1, :aggregate => :sum)
    # @set is now: [[d, 0], [a, 1], [c, 4], [b, 6]]
    @set.members.should == ['d', 'a', 'c', 'b']

    @set_1.unionstore(@set, @set_2, :aggregate => :min)
    # @set is now: [[d, 0], [a, 1], [c, 1], [b, 2]]
    @set.members.should == ['d', 'a', 'c', 'b']
    @set['b'].should == 2

    @set_1.unionstore(@set, @set_2, :aggregate => :max)
    # @set is now: [[d, 0], [a, 1], [c, 3], [b, 4]]
    @set.members.should == ['d', 'a', 'c', 'b']
    @set['b'].should == 4

    @set_1.unionstore(@set, @set_2, :aggregate => :sum, :weights => [0, 1])
    # @set is now: [[a, 0], [d, 0], [c, 1], [b, 2]]
    @set.members.should == ['a', 'd', 'c', 'b']
    @set['b'].should == 2

    @set_5 << ['a', 'e', 'f']
    @set_1.unionstore(@set, @set_5, :aggregate => :sum)
    # #set is now: [[e, 1], [f, 1], [a, 1], [c, 3], [b, 4]]
    @set.members.should == ['e', 'f', 'a', 'c', 'b']
    @set['e'].should == 1
  end

  it "should handle intersections" do
    @set_1.add('a', 1)
    @set_1.add('b', 4)
    @set_1.add('c', 3)

    @set_2.add('b', 2)
    @set_2.add('c', 1)
    @set_2.add('d', 0)

    @set_1.interstore(@set.key, @set_2)
    # @set is now: [[c, 4], [b, 6]]
    @set.members.should == ['c', 'b']

    @set_2.interstore(@set, @set_1, :aggregate => :sum)
    # @set is now: [[c, 4], [b, 6]]
    @set.members.should == ['c', 'b']

    @set_1.interstore(@set, @set_2, :aggregate => :min)
    # @set is now: [[c, 1], [b, 2]]
    @set.members.should == ['c', 'b']
    @set['b'].should == 2

    @set_5 << ['a', 'e', 'b']
    @set_1.interstore(@set, @set_5, :aggregate => :max)
    # @set is now: [[a, 1], [b, 4]]
    @set.members.should == ['a', 'b']
    @set['b'].should == 4
  end

  it 'should set time to live in seconds when expiration option assigned' do
    @set = Redis::SortedSet.new('spec/zset', :expiration => 10)
    @set['val'] = 1
    @set.ttl.should > 0
    @set.ttl.should <= 10
  end

  it 'should set expiration when expireat option assigned' do
    @set = Redis::SortedSet.new('spec/zset', :expireat => Time.now + 10.seconds)
    @set['val'] = 1
    @set.ttl.should > 0
    @set.ttl.should <= 10
  end

  it "should respond to #value" do
    @set['val'] = 1
    @set.value.should == @set.members
    @set.value.should == ['val']
  end

  it "should respond to #to_json" do
    @set['val'] = 1
    JSON.parse(@set.to_json)['value'].should == ['val']
  end

  it "should respond to #as_json" do
    @set['val'] = 1
    @set.as_json['value'].should == ['val']
  end

  describe "with expiration" do
    [:[]=, :add, :increment, :incr, :incrby, :decrement, :decr, :decrby].each do |meth|
      it "#{meth} expiration: option" do
        @set = Redis::SortedSet.new('spec/zset_exp', :expiration => 10)
        @set.clear
        @set.send(meth, 'somekey', 12)
        @set.ttl.should > 0
        @set.ttl.should <= 10
      end
      it "#{meth} expireat: option" do
        @set = Redis::SortedSet.new('spec/zset_exp', :expireat => Time.now + 10.seconds)
        @set.clear
        @set.send(meth, 'somekey', 12)
        @set.ttl.should > 0
        @set.ttl.should <= 10
      end
    end

    [:merge, :add_all].each do |meth|
      it "#{meth} expiration: option" do
        @set = Redis::SortedSet.new('spec/zset_exp', :expiration => 10)
        @set.clear
        @set.send(meth, 'somekey' => 12)
        @set.ttl.should > 0
        @set.ttl.should <= 10
      end
      it "#{meth} expireat: option" do
        @set = Redis::SortedSet.new('spec/zset_exp', :expireat => Time.now + 10.seconds)
        @set.clear
        @set.send(meth, 'somekey' => 12)
        @set.ttl.should > 0
        @set.ttl.should <= 10
      end
    end

    [:unionstore, :interstore].each do |meth|
      it "#{meth} expiration: option" do
        @set = Redis::SortedSet.new('spec/zset_exp', :expiration => 10)
        @set.clear
        @set.redis.zadd(@set.key, 1, "1")
        @set.send(meth, 'sets', Redis::SortedSet.new('other'))
        @set.ttl.should > 0
        @set.ttl.should <= 10
      end

      it "#{meth} expireat: option" do
        @set = Redis::SortedSet.new('spec/zset_exp', :expireat => Time.now + 10.seconds)
        @set.clear
        @set.redis.zadd(@set.key, 1, "1")
        @set.send(meth, 'sets', Redis::SortedSet.new('other'))
        @set.ttl.should > 0
        @set.ttl.should <= 10
      end
    end

    it "delete expiration: option" do
      @set = Redis::SortedSet.new('spec/zset_exp', :expiration => 10)
      @set.clear
      @set.redis.zadd(@set.key, 1, "1")
      @set.redis.zadd(@set.key, 2, "2")
      @set.delete("2")
      @set.ttl.should > 0
      @set.ttl.should <= 10
    end

    it "delete expireat: option" do
      @set = Redis::SortedSet.new('spec/zset_exp', :expireat => Time.now + 10.seconds)
      @set.clear
      @set.redis.zadd(@set.key, 1, "1")
      @set.redis.zadd(@set.key, 2, "2")
      @set.delete("2")
      @set.ttl.should > 0
      @set.ttl.should <= 10
    end
  end

  after do
    @set.clear
    @set_1.clear
    @set_2.clear
    @set_3.clear
    @set_4.clear
    @set_5.clear
  end
end

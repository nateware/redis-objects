
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Roster
  include Redis::Atoms
  counter :available_slots, :start => 10
  counter :pitchers, :limit => :max_pitchers
  counter :basic
  lock :resort, :timeout => 2

  def initialize(id=1) @id = id end
  def id; @id; end
  def max_pitchers; 3; end
end

describe Redis::Atoms do
  before :all do
    @roster  = Roster.new
    @roster2 = Roster.new
  end
  
  before :each do
    @roster.available_slots.reset
    @roster.pitchers.reset
    @roster.basic.reset
    @roster.resort_lock.clear
  end

  it "should provide a connection method" do
    Roster.redis.should == Redis::Atoms.redis
    Roster.redis.should be_kind_of(Redis)
  end

  it "should create counter accessors" do
    [:available_slots, :pitchers, :basic].each do |m|
       @roster.respond_to?(m).should == true
     end
  end
  
  it "should support increment/decrement of counters" do
    @roster.available_slots.key.should == 'roster:1:available_slots'
    @roster.available_slots.to_i.should == 10
    
    # math proxy ops
    (@roster.available_slots == 10).should be_true
    (@roster.available_slots <= 10).should be_true
    (@roster.available_slots < 11).should be_true
    (@roster.available_slots > 9).should be_true
    (@roster.available_slots >= 10).should be_true
    "#{@roster.available_slots}".should == "10"

    @roster.available_slots.increment.should == 11
    @roster.available_slots.increment.should == 12
    @roster2.available_slots.increment.should == 13
    @roster2.available_slots.increment(2).should == 15
    @roster.available_slots.decrement.should == 14
    @roster2.available_slots.decrement.should == 13
    @roster.available_slots.decrement.should == 12
    @roster2.available_slots.decrement(4).should == 8
    @roster.available_slots.to_i.should == 12
    @roster.available_slots.get.should == 8
    @roster.available_slots.reset.should == 10
    @roster.available_slots.to_i.should == 10
    @roster.available_slots.reset(15).should == 15
    @roster.available_slots.should == 15
    @roster.pitchers.increment.should == 1
    @roster.basic.increment.should == 1
    @roster2.basic.decrement.should == 0
    @roster.basic.get.should == 0
  end
  
  it "should support class-level increment/decrement of counters" do
    Roster.get_counter(:available_slots, @roster.id).should == 10
    Roster.increment_counter(:available_slots, @roster.id).should == 11
    Roster.increment_counter(:available_slots, @roster.id, 3).should == 14
    Roster.decrement_counter(:available_slots, @roster.id, 2).should == 12
    Roster.decrement_counter(:available_slots, @roster.id).should == 11
    Roster.reset_counter(:available_slots, @roster.id).should == true
    Roster.get_counter(:available_slots, @roster.id).should == 10
  end

  it "should take an atomic block for increment/decrement" do
    a = false
    @roster.available_slots.to_i.should == 10
    @roster.available_slots.decr do |cnt|
      if cnt >= 0
        a = true
      end
    end
    @roster.available_slots.to_i.should == 9
    a.should be_true
    
    @roster.available_slots.to_i.should == 9
    @roster.available_slots.decr do |cnt|
      @roster.available_slots.to_i.should == 8
      false
    end
    @roster.available_slots.to_i.should == 8
    
    @roster.available_slots.to_i.should == 8
    @roster.available_slots.decr do |cnt|
      @roster.available_slots.to_i.should == 7
      nil  # should rewind
    end
    @roster.available_slots.to_i.should == 8
    
    @roster.available_slots.to_i.should == 8
    @roster.available_slots.incr do |cnt|
      if 1 == 2  # should rewind
        true
      end
    end
    @roster.available_slots.to_i.should == 8

    @roster.available_slots.to_i.should == 8
    @roster.available_slots.incr do |cnt|
      @roster.available_slots.to_i.should == 9
      []
    end
    @roster.available_slots.to_i.should == 9

    @roster.available_slots.to_i.should == 9
    begin
      @roster.available_slots.decr do |cnt|
        @roster.available_slots.to_i.should == 8
        raise 'oops'
      end
    rescue
    end
    @roster.available_slots.should == 9
    
    # check return value from the block
    value =
      @roster.available_slots.decr do |cnt|
        @roster.available_slots.to_i.should == 8
        42
      end
    value.should == 42
    @roster.available_slots.should == 8
  end

  it "should take an atomic block for increment/decrement class methods" do
    a = false
    Roster.get_counter(:available_slots, @roster.id).should == 10
    Roster.decrement_counter(:available_slots, @roster.id) do |cnt|
      if cnt >= 0
        a = true
      end
    end
    Roster.get_counter(:available_slots, @roster.id).should == 9
    a.should be_true

    Roster.get_counter(:available_slots, @roster.id).should == 9
    Roster.decrement_counter(:available_slots, @roster.id) do |cnt|
      Roster.get_counter(:available_slots, @roster.id).should == 8
      false
    end
    Roster.get_counter(:available_slots, @roster.id).should == 8

    Roster.get_counter(:available_slots, @roster.id).should == 8
    Roster.decrement_counter(:available_slots, @roster.id) do |cnt|
      Roster.get_counter(:available_slots, @roster.id).should == 7
      nil  # should rewind
    end
    Roster.get_counter(:available_slots, @roster.id).should == 8

    Roster.get_counter(:available_slots, @roster.id).should == 8
    Roster.increment_counter(:available_slots, @roster.id) do |cnt|
      if 1 == 2  # should rewind
        true
      end
    end
    Roster.get_counter(:available_slots, @roster.id).should == 8

    Roster.get_counter(:available_slots, @roster.id).should == 8
    Roster.increment_counter(:available_slots, @roster.id) do |cnt|
      Roster.get_counter(:available_slots, @roster.id).should == 9
      []
    end
    Roster.get_counter(:available_slots, @roster.id).should == 9

    Roster.get_counter(:available_slots, @roster.id).should == 9
    begin
      Roster.decrement_counter(:available_slots, @roster.id) do |cnt|
        Roster.get_counter(:available_slots, @roster.id).should == 8
        raise 'oops'
      end
    rescue
    end
    Roster.get_counter(:available_slots, @roster.id).should == 9

    # check return value from the block
    value =
      Roster.decrement_counter(:available_slots, @roster.id) do |cnt|
        Roster.get_counter(:available_slots, @roster.id).should == 8
        42
      end
    value.should == 42
    Roster.get_counter(:available_slots, @roster.id).should == 8
  end

  it "should properly throw errors on bad counters" do
    error = nil
    begin
      Roster.increment_counter(:badness, 2)
    rescue => error
    end
    error.should be_kind_of(Redis::Atoms::UndefinedAtom)

    error = nil
    begin
      Roster.obtain_lock(:badness, 2){}
    rescue => error
    end
    error.should be_kind_of(Redis::Atoms::UndefinedAtom)

    error = nil
    begin
      @roster.available_slots = 42
    rescue => error
    end
    error.should be_kind_of(NoMethodError)

    error = nil
    begin
      @roster.available_slots += 69
    rescue => error
    end
    error.should be_kind_of(NoMethodError)

    error = nil
    begin
      @roster.available_slots -= 15
    rescue => error
    end
    error.should be_kind_of(NoMethodError)
  end
  
  it "should provide a lock method that accepts a block" do
    @roster.resort_lock.key.should == 'roster:1:resort_lock'
    a = false
    @roster.resort_lock.lock do
      a = true
    end
    a.should be_true
  end
  
  it "should raise an exception if the timeout is exceeded" do
    @roster.redis.set(@roster.resort_lock.key, 1)
    error = nil
    begin
      @roster.resort_lock.lock {}
    rescue => error
    end
    error.should_not be_nil
    error.should be_kind_of(Redis::Atoms::LockTimeout)
  end
end

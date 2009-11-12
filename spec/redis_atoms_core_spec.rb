
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Roster
  include Redis::Atoms
  counter :available_slots, :start => 10, :type => :decrement
  counter :pitchers, :limit => :max_pitchers
  counter :basic
  lock :resort, :timeout => 2

  def id; 1; end
  def max_pitchers; 3; end
end

describe Redis::Atoms do
  before :all do
    @roster  = Roster.new
    @roster2 = Roster.new

    @roster.clear_available_slots
    @roster.clear_pitchers
    @roster.clear_basic
    @roster.clear_resort_lock
  end

  after :each do
    @roster.reset_available_slots
    @roster.reset_pitchers
    @roster.reset_basic
    @roster.clear_resort_lock
  end

  it "should provide a connection method" do
    Roster.redis.should == Redis::Atoms.redis
    Roster.redis.should be_kind_of(Redis)
  end

  it "should create counter accessors" do
    [:available_slots, :increment_available_slots, :decrement_available_slots,
     :reset_available_slots, :clear_available_slots].each do |m|
       @roster.respond_to?(m).should == true
     end
  end
  
  it "should support increment/decrement of counters" do
    @roster.available_slots_counter_name.should == 'roster:1:available_slots'
    @roster.available_slots.should == 10
    @roster.increment_available_slots.should == 11
    @roster.increment_available_slots.should == 12
    @roster2.increment_available_slots.should == 13
    @roster2.increment_available_slots(2).should == 15
    @roster.decrement_available_slots.should == 14
    @roster2.decrement_available_slots.should == 13
    @roster.decrement_available_slots.should == 12
    @roster2.decrement_available_slots(4).should == 8
    @roster.available_slots.should == 8
    @roster.reset_available_slots.should == true
    @roster.available_slots.should == 10
    @roster.reset_available_slots(15).should == true
    @roster.available_slots.should == 15
    @roster.increment_pitchers.should == 1
    @roster.increment_basic.should == 1
    @roster2.decrement_basic.should == 0
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

  it "should provide an if_counter method with defaults" do
    a = false
    @roster.if_available_slots_free do
      a = true
    end
    a.should be_true

    @roster.available_slots.should == 9
    begin
      @roster.if_available_slots_free do
        @roster.available_slots.should == 8
        raise 'oops'
      end
    rescue
    end
    @roster.available_slots.should == 9

    a = false
    Roster.if_counter_free(:available_slots, @roster.id) do
      a = true
    end
    a.should be_true
    Roster.get_counter(:available_slots, @roster.id).should == 8
    
    begin
      Roster.if_counter_free(:available_slots, @roster.id) do
        Roster.get_counter(:available_slots, @roster.id).should == 7
        raise 'oops2'
      end
    rescue
    end
    Roster.get_counter(:available_slots, @roster.id).should == 8
  end

  it "should handle a symbol passed to :limit as a method callback" do
    @roster.increment_pitchers.should == 1
    @roster.increment_pitchers.should == 2
    a = false
    @roster.if_pitchers_free do
      a = true
    end
    a.should be_true
    a = false
    @roster.if_pitchers_free do
      a = true
    end
    a.should be_false
  end

  it "should properly throw errors on bad counters" do
    error = nil
    begin
      Roster.increment_counter(:badness, 2)
    rescue => error
    end
    error.should_not be_nil
    error.should be_kind_of(Redis::Atoms::UndefinedCounter)
  end
  
  it "should provide a lock method that accepts a block" do
    @roster.resort_lock_name.should == 'roster:1:resort_lock'
    a = false
    @roster.lock_resort do
      a = true
    end
    a.should be_true
  end
  
  it "should raise an exception if the timeout is exceeded" do
    @roster.redis.set(@roster.resort_lock_name, 1)
    error = nil
    begin
      @roster.lock_resort {}
    rescue => error
    end
    error.should_not be_nil
    error.should be_kind_of(Redis::Atoms::LockTimeout)
  end
end

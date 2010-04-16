
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'
Redis::Objects.redis = $redis

class Roster
  include Redis::Objects
  counter :available_slots, :start => 10
  counter :pitchers, :limit => :max_pitchers
  counter :basic
  lock :resort, :timeout => 2
  value :starting_pitcher, :marshal => true
  list :player_stats, :marshal => true
  set :outfielders, :marshal => true

  # global class counters
  counter :total_players_online, :global => true
  list :all_player_stats, :global => true
  set :all_players_online, :global => true
  value :last_player, :global => true
  
  # custom keys
  counter :player_totals, :key => 'players/#{username}/total'
  list :all_player_stats, :key => 'players:all_stats'
  set :total_wins, :key => 'players:#{id}:all_stats'
  value :my_rank, :key => 'players:my_rank:#{username}'
  value :weird_key, :key => 'players:weird_key:#{raise}', :global => true

  def initialize(id=1) @id = id end
  def id; @id; end
  def username; "user#{id}"; end
  def max_pitchers; 3; end
end

describe Redis::Objects do
  before :all do
    @roster  = Roster.new
    @roster2 = Roster.new
    
    @roster_1 = Roster.new(1)
    @roster_2 = Roster.new(2)
    @roster_3 = Roster.new(3)
  end
  
  before :each do
    @roster.available_slots.reset
    @roster.pitchers.reset
    @roster.basic.reset
    @roster.resort_lock.clear
    @roster.starting_pitcher.delete
    @roster.player_stats.clear
    @roster.outfielders.clear
    @roster_1.outfielders.clear
    @roster_2.outfielders.clear
    @roster_3.outfielders.clear
    @roster.redis.del(UNIONSTORE_KEY)
    @roster.redis.del(INTERSTORE_KEY)
    @roster.redis.del(DIFFSTORE_KEY)

    Roster.total_players_online.reset
    Roster.all_player_stats.clear
    Roster.all_players_online.clear
    Roster.last_player.delete
    Roster.weird_key.clear
    
    @roster.player_totals.clear
    @roster.all_player_stats.clear
    @roster.total_wins.clear
    @roster.my_rank.clear
  end

  it "should provide a connection method" do
    Roster.redis.should == Redis::Objects.redis
    # Roster.redis.should be_kind_of(Redis)
  end
  
  it "should support custom key names" do
    @roster.player_totals.incr
    @roster.redis.get('players/user1/total').should == '1'
    @roster.redis.get('players/#{username}/total').should be_nil
    @roster.all_player_stats << 'a'
    @roster.redis.lindex('players:all_stats', 0).should == 'a'
    @roster.total_wins << 'a'
    @roster.redis.smembers('players:1:all_stats').should == ['a']
    @roster.redis.smembers('players:#{id}:all_stats').should == []
    @roster.my_rank = 'a'
    @roster.redis.get('players:my_rank:user1').should == 'a'
    Roster.weird_key = 'tuka'
    Roster.redis.get('players:weird_key:#{raise}').should == 'tuka'
  end

  it "should create counter accessors" do
    [:available_slots, :pitchers, :basic].each do |m|
       @roster.respond_to?(m).should == true
     end
  end
  
  it "should support increment/decrement of counters" do
    @roster.available_slots.key.should == 'roster:1:available_slots'
    @roster.available_slots.should == 10
    
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
    @roster.available_slots.should == 8
    @roster.available_slots.reset.should be_true
    @roster.available_slots.should == 10
    @roster.available_slots.reset(15).should be_true
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

  it "should support class-level increment/decrement of global counters" do
    Roster.total_players_online.should == 0
    Roster.total_players_online.increment.should == 1
    Roster.total_players_online.decrement.should == 0
    Roster.total_players_online.increment(3).should == 3
    Roster.total_players_online.decrement(2).should == 1
    Roster.total_players_online.reset.should be_true
    Roster.total_players_online.should == 0
    
    Roster.get_counter(:total_players_online).should == 0
    Roster.increment_counter(:total_players_online).should == 1
    Roster.increment_counter(:total_players_online, nil, 3).should == 4
    Roster.decrement_counter(:total_players_online, nil, 2).should == 2
    Roster.decrement_counter(:total_players_online).should == 1
    Roster.reset_counter(:total_players_online).should == true
    Roster.get_counter(:total_players_online).should == 0
  end

  it "should take an atomic block for increment/decrement" do
    a = false
    @roster.available_slots.should == 10
    @roster.available_slots.decr do |cnt|
      if cnt >= 0
        a = true
      end
    end
    @roster.available_slots.should == 9
    a.should be_true
    
    @roster.available_slots.should == 9
    @roster.available_slots.decr do |cnt|
      @roster.available_slots.should == 8
      false
    end
    @roster.available_slots.should == 8
    
    @roster.available_slots.should == 8
    @roster.available_slots.decr do |cnt|
      @roster.available_slots.should == 7
      nil  # should rewind
    end
    @roster.available_slots.should == 8
    
    @roster.available_slots.should == 8
    @roster.available_slots.incr do |cnt|
      if 1 == 2  # should rewind
        true
      end
    end
    @roster.available_slots.should == 8

    @roster.available_slots.should == 8
    @roster.available_slots.incr do |cnt|
      @roster.available_slots.should == 9
      []
    end
    @roster.available_slots.should == 9

    @roster.available_slots.should == 9
    begin
      @roster.available_slots.decr do |cnt|
        @roster.available_slots.should == 8
        raise 'oops'
      end
    rescue
    end
    @roster.available_slots.should == 9
    
    # check return value from the block
    value =
      @roster.available_slots.decr do |cnt|
        @roster.available_slots.should == 8
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
    error.should be_kind_of(Redis::Objects::UndefinedCounter)

    error = nil
    begin
      Roster.obtain_lock(:badness, 2){}
    rescue => error
    end
    error.should be_kind_of(Redis::Objects::UndefinedLock)

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

  it "should support obtain_lock as a class method" do
    error = nil
    begin
      Roster.obtain_lock(:resort, 2) do
        Roster.redis.get("roster:2:resort_lock").should_not be_nil
      end
    rescue => error
    end

    error.should be_nil
    Roster.redis.get("roster:2:resort_lock").should be_nil
  end
  
  it "should handle simple values" do
    @roster.starting_pitcher.should == nil
    @roster.starting_pitcher = 'Trevor Hoffman'
    @roster.starting_pitcher.should == 'Trevor Hoffman'
    @roster.starting_pitcher.get.should == 'Trevor Hoffman'
    @roster.starting_pitcher = 'Tom Selleck'
    @roster.starting_pitcher.should == 'Tom Selleck'
    @roster.starting_pitcher.del.should be_true
    @roster.starting_pitcher.should be_nil
  end

  it "should handle complex marshaled values" do
    @roster.starting_pitcher.should == nil
    @roster.starting_pitcher = {:json => 'data'}
    @roster.starting_pitcher.should == {:json => 'data'}
    @roster.starting_pitcher.get.should == {:json => 'data'}
    @roster.starting_pitcher.del.should be_true
    @roster.starting_pitcher.should be_nil
  end

  it "should handle lists of simple values" do
    @roster.player_stats.should be_empty
    @roster.player_stats << 'a'
    @roster.player_stats.should == ['a']
    @roster.player_stats.get.should == ['a']
    @roster.player_stats.unshift 'b'
    @roster.player_stats.to_s.should == 'b, a'
    @roster.player_stats.should == ['b','a']
    @roster.player_stats.get.should == ['b','a']
    @roster.player_stats.push 'c'
    @roster.player_stats.should == ['b','a','c']
    @roster.player_stats.get.should == ['b','a','c']
    @roster.player_stats.first.should == 'b'
    @roster.player_stats.last.should == 'c'
    @roster.player_stats << 'd'
    @roster.player_stats.should == ['b','a','c','d']
    @roster.player_stats[1].should == 'a'
    @roster.player_stats[0].should == 'b'
    @roster.player_stats[2].should == 'c'
    @roster.player_stats[3].should == 'd'
    @roster.player_stats.include?('c').should be_true
    @roster.player_stats.include?('no').should be_false
    @roster.player_stats.pop.should == 'd'
    @roster.player_stats[0].should == @roster.player_stats.at(0)
    @roster.player_stats[1].should == @roster.player_stats.at(1)
    @roster.player_stats[2].should == @roster.player_stats.at(2)
    @roster.player_stats.should == ['b','a','c']
    @roster.player_stats.get.should == ['b','a','c']
    @roster.player_stats.shift.should == 'b'
    @roster.player_stats.should == ['a','c']
    @roster.player_stats.get.should == ['a','c']
    @roster.player_stats << 'e' << 'f' << 'e'
    @roster.player_stats.should == ['a','c','e','f','e']
    @roster.player_stats.get.should == ['a','c','e','f','e']
    @roster.player_stats.delete('e').should == 2
    @roster.player_stats.should == ['a','c','f']
    @roster.player_stats.get.should == ['a','c','f']
    @roster.player_stats << 'j'
    @roster.player_stats.should == ['a','c','f','j']
    @roster.player_stats[0..2].should == ['a','c','f']
    @roster.player_stats[1, 3].should == ['c','f','j']
    @roster.player_stats.length.should == 4
    @roster.player_stats.size.should == 4
    @roster.player_stats.should == ['a','c','f','j']
    @roster.player_stats.get.should == ['a','c','f','j']

    i = -1
    @roster.player_stats.each do |st|
      st.should == @roster.player_stats[i += 1]
    end
    @roster.player_stats.should == ['a','c','f','j']
    @roster.player_stats.get.should == ['a','c','f','j']

    @roster.player_stats.each_with_index do |st,i|
      st.should == @roster.player_stats[i]
    end
    @roster.player_stats.should == ['a','c','f','j']
    @roster.player_stats.get.should == ['a','c','f','j']

    coll = @roster.player_stats.collect{|st| st}
    coll.should == ['a','c','f','j']
    @roster.player_stats.should == ['a','c','f','j']
    @roster.player_stats.get.should == ['a','c','f','j']

    @roster.player_stats << 'a'
    coll = @roster.player_stats.select{|st| st == 'a'}
    coll.should == ['a','a']
    @roster.player_stats.should == ['a','c','f','j','a']
    @roster.player_stats.get.should == ['a','c','f','j','a']
  end

  it "should handle sets of simple values" do
    @roster.outfielders.should be_empty
    @roster.outfielders << 'a' << 'a' << 'a'
    @roster.outfielders.should == ['a']
    @roster.outfielders.get.should == ['a']
    @roster.outfielders << 'b' << 'b'
    @roster.outfielders.to_s.should == 'a, b'
    @roster.outfielders.should == ['a','b']
    @roster.outfielders.members.should == ['a','b']
    @roster.outfielders.get.should == ['a','b']
    @roster.outfielders << 'c'
    @roster.outfielders.sort.should == ['a','b','c']
    @roster.outfielders.get.sort.should == ['a','b','c']
    @roster.outfielders.delete('c')
    @roster.outfielders.should == ['a','b']
    @roster.outfielders.get.sort.should == ['a','b']
    @roster.outfielders.length.should == 2
    @roster.outfielders.size.should == 2
    
    i = 0
    @roster.outfielders.each do |st|
      i += 1
    end
    i.should == @roster.outfielders.length

    coll = @roster.outfielders.collect{|st| st}
    coll.should == ['a','b']
    @roster.outfielders.should == ['a','b']
    @roster.outfielders.get.should == ['a','b']

    @roster.outfielders << 'c'
    @roster.outfielders.member?('c').should be_true
    @roster.outfielders.include?('c').should be_true
    @roster.outfielders.member?('no').should be_false
    coll = @roster.outfielders.select{|st| st == 'c'}
    coll.should == ['c']
    @roster.outfielders.sort.should == ['a','b','c']
  end
  
  it "should handle set intersections and unions" do
    @roster_1.outfielders << 'a' << 'b' << 'c' << 'd' << 'e'
    @roster_2.outfielders << 'c' << 'd' << 'e' << 'f' << 'g'
    @roster_3.outfielders << 'a' << 'd' << 'g' << 'l' << 'm'
    @roster_1.outfielders.sort.should == %w(a b c d e)
    @roster_2.outfielders.sort.should == %w(c d e f g)
    @roster_3.outfielders.sort.should == %w(a d g l m)
    (@roster_1.outfielders & @roster_2.outfielders).sort.should == ['c','d','e']
    @roster_1.outfielders.intersection(@roster_2.outfielders).sort.should == ['c','d','e']
    @roster_1.outfielders.intersection(@roster_2.outfielders, @roster_3.outfielders).sort.should == ['d']
    @roster_1.outfielders.intersect(@roster_2.outfielders).sort.should == ['c','d','e']
    @roster_1.outfielders.inter(@roster_2.outfielders, @roster_3.outfielders).sort.should == ['d']
    @roster_1.outfielders.interstore(INTERSTORE_KEY, @roster_2.outfielders).should == 3
    @roster_1.redis.smembers(INTERSTORE_KEY).sort.should == ['c','d','e']
    @roster_1.outfielders.interstore(INTERSTORE_KEY, @roster_2.outfielders, @roster_3.outfielders).should == 1
    @roster_1.redis.smembers(INTERSTORE_KEY).sort.should == ['d']

    (@roster_1.outfielders | @roster_2.outfielders).sort.should == ['a','b','c','d','e','f','g']
    (@roster_1.outfielders + @roster_2.outfielders).sort.should == ['a','b','c','d','e','f','g']
    @roster_1.outfielders.union(@roster_2.outfielders).sort.should == ['a','b','c','d','e','f','g']
    @roster_1.outfielders.union(@roster_2.outfielders, @roster_3.outfielders).sort.should == ['a','b','c','d','e','f','g','l','m']
    @roster_1.outfielders.unionstore(UNIONSTORE_KEY, @roster_2.outfielders).should == 7
    @roster_1.redis.smembers(UNIONSTORE_KEY).sort.should == ['a','b','c','d','e','f','g']
    @roster_1.outfielders.unionstore(UNIONSTORE_KEY, @roster_2.outfielders, @roster_3.outfielders).should == 9
    @roster_1.redis.smembers(UNIONSTORE_KEY).sort.should == ['a','b','c','d','e','f','g','l','m']
  end

  it "should handle class-level global lists of simple values" do
    Roster.all_player_stats.should be_empty
    Roster.all_player_stats << 'a'
    Roster.all_player_stats.should == ['a']
    Roster.all_player_stats.get.should == ['a']
    Roster.all_player_stats.unshift 'b'
    Roster.all_player_stats.to_s.should == 'b, a'
    Roster.all_player_stats.should == ['b','a']
    Roster.all_player_stats.get.should == ['b','a']
    Roster.all_player_stats.push 'c'
    Roster.all_player_stats.should == ['b','a','c']
    Roster.all_player_stats.get.should == ['b','a','c']
    Roster.all_player_stats.first.should == 'b'
    Roster.all_player_stats.last.should == 'c'
    Roster.all_player_stats << 'd'
    Roster.all_player_stats.should == ['b','a','c','d']
    Roster.all_player_stats[1].should == 'a'
    Roster.all_player_stats[0].should == 'b'
    Roster.all_player_stats[2].should == 'c'
    Roster.all_player_stats[3].should == 'd'
    Roster.all_player_stats.include?('c').should be_true
    Roster.all_player_stats.include?('no').should be_false
    Roster.all_player_stats.pop.should == 'd'
    Roster.all_player_stats[0].should == Roster.all_player_stats.at(0)
    Roster.all_player_stats[1].should == Roster.all_player_stats.at(1)
    Roster.all_player_stats[2].should == Roster.all_player_stats.at(2)
    Roster.all_player_stats.should == ['b','a','c']
    Roster.all_player_stats.get.should == ['b','a','c']
    Roster.all_player_stats.shift.should == 'b'
    Roster.all_player_stats.should == ['a','c']
    Roster.all_player_stats.get.should == ['a','c']
    Roster.all_player_stats << 'e' << 'f' << 'e'
    Roster.all_player_stats.should == ['a','c','e','f','e']
    Roster.all_player_stats.get.should == ['a','c','e','f','e']
    Roster.all_player_stats.delete('e').should == 2
    Roster.all_player_stats.should == ['a','c','f']
    Roster.all_player_stats.get.should == ['a','c','f']
    Roster.all_player_stats << 'j'
    Roster.all_player_stats.should == ['a','c','f','j']
    Roster.all_player_stats[0..2].should == ['a','c','f']
    Roster.all_player_stats[1, 3].should == ['c','f','j']
    Roster.all_player_stats.length.should == 4
    Roster.all_player_stats.size.should == 4
    Roster.all_player_stats.should == ['a','c','f','j']
    Roster.all_player_stats.get.should == ['a','c','f','j']

    i = -1
    Roster.all_player_stats.each do |st|
      st.should == Roster.all_player_stats[i += 1]
    end
    Roster.all_player_stats.should == ['a','c','f','j']
    Roster.all_player_stats.get.should == ['a','c','f','j']

    Roster.all_player_stats.each_with_index do |st,i|
      st.should == Roster.all_player_stats[i]
    end
    Roster.all_player_stats.should == ['a','c','f','j']
    Roster.all_player_stats.get.should == ['a','c','f','j']

    coll = Roster.all_player_stats.collect{|st| st}
    coll.should == ['a','c','f','j']
    Roster.all_player_stats.should == ['a','c','f','j']
    Roster.all_player_stats.get.should == ['a','c','f','j']

    Roster.all_player_stats << 'a'
    coll = Roster.all_player_stats.select{|st| st == 'a'}
    coll.should == ['a','a']
    Roster.all_player_stats.should == ['a','c','f','j','a']
    Roster.all_player_stats.get.should == ['a','c','f','j','a']
  end

  it "should handle class-level global sets of simple values" do
    Roster.all_players_online.should be_empty
    Roster.all_players_online << 'a' << 'a' << 'a'
    Roster.all_players_online.should == ['a']
    Roster.all_players_online.get.should == ['a']
    Roster.all_players_online << 'b' << 'b'
    Roster.all_players_online.to_s.should == 'a, b'
    Roster.all_players_online.should == ['a','b']
    Roster.all_players_online.members.should == ['a','b']
    Roster.all_players_online.get.should == ['a','b']
    Roster.all_players_online << 'c'
    Roster.all_players_online.sort.should == ['a','b','c']
    Roster.all_players_online.get.sort.should == ['a','b','c']
    Roster.all_players_online.delete('c')
    Roster.all_players_online.should == ['a','b']
    Roster.all_players_online.get.sort.should == ['a','b']
    Roster.all_players_online.length.should == 2
    Roster.all_players_online.size.should == 2
    
    i = 0
    Roster.all_players_online.each do |st|
      i += 1
    end
    i.should == Roster.all_players_online.length

    coll = Roster.all_players_online.collect{|st| st}
    coll.should == ['a','b']
    Roster.all_players_online.should == ['a','b']
    Roster.all_players_online.get.should == ['a','b']

    Roster.all_players_online << 'c'
    Roster.all_players_online.member?('c').should be_true
    Roster.all_players_online.include?('c').should be_true
    Roster.all_players_online.member?('no').should be_false
    coll = Roster.all_players_online.select{|st| st == 'c'}
    coll.should == ['c']
    Roster.all_players_online.sort.should == ['a','b','c']
  end
  
  it "should handle class-level global values" do
    Roster.last_player.should == nil
    Roster.last_player = 'Trevor Hoffman'
    Roster.last_player.should == 'Trevor Hoffman'
    Roster.last_player.get.should == 'Trevor Hoffman'
    Roster.last_player = 'Tom Selleck'
    Roster.last_player.should == 'Tom Selleck'
    Roster.last_player.del.should be_true
    Roster.last_player.should be_nil
  end

  it "should easily enable @object.class.global_objects" do
    @roster.class.all_players_online.should be_empty
    @roster.class.all_players_online << 'a' << 'a' << 'a'
    @roster.class.all_players_online.should == ['a']
    @roster2.class.all_players_online.should == ['a']

    @roster.all_players_online.should == ['a']
    @roster2.all_players_online.should == ['a']

    @roster.class.all_player_stats.should be_empty
    @roster.class.all_player_stats << 'a'
    @roster.class.all_player_stats.should == ['a']
    @roster.class.all_player_stats.get.should == ['a']
    @roster.class.all_player_stats.unshift 'b'
    @roster.class.all_player_stats.to_s.should == 'b, a'
    @roster.class.all_player_stats.should == ['b','a']
    @roster2.class.all_player_stats.should == ['b','a']

    @roster.all_player_stats.should == ['b','a']
    @roster2.all_player_stats.should == ['b','a']
    @roster2.all_player_stats << 'b'
    @roster.all_player_stats.should == ['b','a','b']
    
    @roster.last_player.should == nil
    @roster.class.last_player = 'Trevor Hoffman'
    @roster.last_player.should == 'Trevor Hoffman'
    @roster.last_player.get.should == 'Trevor Hoffman'
    @roster2.last_player.get.should == 'Trevor Hoffman'
    @roster2.last_player = 'Tom Selleck'
    @roster.last_player.should == 'Tom Selleck'
    @roster.last_player.del.should be_true
    @roster.last_player.should be_nil
    @roster2.last_player.should be_nil
  end

  it "should handle lists of complex data types" do
    @roster.player_stats << {:json => 'data'}
    @roster.player_stats << {:json2 => 'data2'}
    @roster.player_stats.first.should == {:json => 'data'}
    @roster.player_stats.last.should == {:json2 => 'data2'}
    @roster.player_stats << [1,2,3,[4,5]]
    @roster.player_stats.last.should == [1,2,3,[4,5]]
    @roster.player_stats.shift.should == {:json => 'data'}
  end
  
  it "should handle sets of complex data types" do
    @roster.outfielders << {:a => 1} << {:b => 2}
    @roster.outfielders.member?({:b => 2})
    @roster.outfielders.members.should == [{:b => 2}, {:a => 1}]
    @roster_1.outfielders << {:a => 1} << {:b => 2}
    @roster_2.outfielders << {:b => 2} << {:c => 3}
    (@roster_1.outfielders & @roster_2.outfielders).should == [{:b => 2}]
    (@roster_1.outfielders | @roster_2.outfielders).should == [{:b=>2}, {:c=>3}, {:a=>1}]
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
    error.should be_kind_of(Redis::Lock::LockTimeout)
  end
end

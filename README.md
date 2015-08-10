Redis::Objects - Map Redis types directly to Ruby objects
=========================================================

[![Build Status](https://travis-ci.org/nateware/redis-objects.png)](https://travis-ci.org/nateware/redis-objects)
[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MJF7JU5M7F8VL)

This is **not** an ORM. People that are wrapping ORM’s around Redis are missing the point.

The killer feature of Redis is that it allows you to perform _atomic_ operations
on _individual_ data structures, like counters, lists, and sets.  The **atomic** part is HUGE.
Using an ORM wrapper that retrieves a "record", updates values, then sends those values back,
_removes_ the atomicity, cutting the nuts off the major advantage of Redis.  Just use MySQL, k?

This gem provides a Rubyish interface to Redis, by mapping [Redis data types](http://redis.io/commands)
to Ruby objects, via a thin layer over the `redis` gem.  It offers several advantages
over the lower-level redis-rb API:

1. Easy to integrate directly with existing ORMs - ActiveRecord, DataMapper, etc.  Add counters to your model!
2. Complex data structures are automatically Marshaled (if you set :marshal => true)
3. Integers are returned as integers, rather than '17'
4. Higher-level types are provided, such as Locks, that wrap multiple calls

This gem originally arose out of a need for high-concurrency atomic operations;
for a fun rant on the topic, see [An Atomic Rant](http://nateware.com/2010/02/18/an-atomic-rant),
or scroll down to [Atomic Counters and Locks](#atomicity) in this README.

There are two ways to use Redis::Objects, either as an include in a model class (to
tightly integrate with ORMs or other classes), or standalone by using classes such
as `Redis::List` and `Redis::SortedSet`.

Installation and Setup
----------------------
Add it to your Gemfile as:

~~~ruby
gem 'redis-objects'
~~~

Redis::Objects needs a handle created by `Redis.new` or a [ConnectionPool](https://github.com/mperham/connection_pool):

The recommended approach is to use a `ConnectionPool` since this guarantees that most timeouts in the `redis` client
do not pollute your existing connection. However, you need to make sure that both `:timeout` and `:size` are set appropriately
in a multithreaded environment.
~~~ruby
require 'connection_pool'
Redis::Objects.redis = ConnectionPool.new(size: 5, timeout: 5) { Redis.new(:host => '127.0.0.1', :port => 6379) }
~~~

Redis::Objects can also default to `Redis.current` if `Redis::Objects.redis` is not set.
~~~ruby
Redis.current = Redis.new(:host => '127.0.0.1', :port => 6379)
~~~

(If you're on Rails, `config/initializers/redis.rb` is a good place for this.)
Remember you can use Redis::Objects in any Ruby code.  There are **no** dependencies
on Rails.  Standalone, Sinatra, Resque - no problem.

Alternatively, you can set the `redis` handle directly:

~~~ruby
Redis::Objects.redis = Redis.new(...)
~~~

Finally, you can even set different handles for different classes:

~~~ruby
class User
  include Redis::Objects
end
class Post
  include Redis::Objects
end

# you can also use a ConnectionPool here as well
User.redis = Redis.new(:host => '1.2.3.4')
Post.redis = Redis.new(:host => '5.6.7.8')
~~~

As of `0.7.0`, `redis-objects` now autoloads the appropriate `Redis::Whatever`
classes on demand.  Previous strategies of individually requiring `redis/list`
or `redis/set` are no longer required.

Option 1: Model Class Include
=============================
Including Redis::Objects in a model class makes it trivial to integrate Redis types
with an existing ActiveRecord, DataMapper, Mongoid, or similar class.  **Redis::Objects
will work with _any_ class that provides an `id` method that returns a unique value.**
Redis::Objects automatically creates keys that are unique to each object, in the format:

    model_name:id:field_name

For illustration purposes, consider this stub class:

~~~ruby
class User
  include Redis::Objects
  counter :my_posts
  def id
    1
  end
end

user = User.new
user.id  # 1
user.my_posts.increment
user.my_posts.increment
user.my_posts.increment
puts user.my_posts.value # 3
user.my_posts.reset
puts user.my_posts.value # 0
user.my_posts.reset 5
puts user.my_posts.value # 5
~~~

Here's an example that integrates several data types with an ActiveRecord model:

~~~ruby
class Team < ActiveRecord::Base
  include Redis::Objects

  lock :trade_players, :expiration => 15  # sec
  value :at_bat
  counter :hits
  counter :runs
  counter :outs
  counter :inning, :start => 1
  list :on_base
  list :coaches, :marshal => true
  set  :outfielders
  hash_key :pitchers_faced  # "hash" is taken by Ruby
  sorted_set :rank, :global => true
end
~~~

Familiar Ruby array operations Just Work (TM):

~~~ruby
@team = Team.find_by_name('New York Yankees')
@team.on_base << 'player1'
@team.on_base << 'player2'
@team.on_base << 'player3'
@team.on_base    # ['player1', 'player2', 'player3']
@team.on_base.pop
@team.on_base.shift
@team.on_base.length  # 1
@team.on_base.delete('player2')
~~~

Sets work too:

~~~ruby
@team.outfielders << 'outfielder1'
@team.outfielders << 'outfielder2'
@team.outfielders << 'outfielder1'   # dup ignored
@team.outfielders  # ['outfielder1', 'outfielder2']
@team.outfielders.each do |player|
  puts player
end
player = @team.outfielders.detect{|of| of == 'outfielder2'}
~~~

And you can do unions and intersections between objects (kinda cool):

~~~ruby
@team1.outfielders | @team2.outfielders   # outfielders on both teams
@team1.outfielders & @team2.outfielders   # in baseball, should be empty :-)
~~~

Counters can be atomically incremented/decremented (but not assigned):

~~~ruby
@team.hits.increment  # or incr
@team.hits.decrement  # or decr
@team.hits.incr(3)    # add 3
@team.runs = 4        # exception
~~~

Defining a different method as the `id` field is easy

~~~ruby
class User
  include Redis::Objects
  redis_id_field :uid
  counter :my_posts
end

user.uid                # 195137a1bdea4473
user.my_posts.increment # 1
~~~

Finally, for free, you get a `redis` method that points directly to a Redis connection:

~~~ruby
Team.redis.get('somekey')
@team = Team.new
@team.redis.get('somekey')
@team.redis.smembers('someset')
~~~

You can use the `redis` handle to directly call any [Redis API command](http://redis.io/commands).

Option 2: Standalone Usage
===========================
There is a Ruby class that maps to each Redis type, with methods for each
[Redis API command](http://redis.io/commands).
Note that calling `new` does not imply it's actually a "new" value - it just
creates a mapping between that Ruby object and the corresponding Redis data
structure, which may already exist on the `redis-server`.

Counters
--------
The `counter_name` is the key stored in Redis.

~~~ruby
@counter = Redis::Counter.new('counter_name')
@counter.increment  # or incr
@counter.decrement  # or decr
@counter.increment(3)
puts @counter.value
~~~

This gem provides a clean way to do atomic blocks as well:

~~~ruby
@counter.increment do |val|
  raise "Full" if val > MAX_VAL  # rewind counter
end
~~~

See the section on [Atomic Counters and Locks](#atomicity) for cool uses of atomic counter blocks.

Locks
-----
A convenience class that wraps the pattern of [using setnx to perform locking](http://redis.io/commands/setnx).

~~~ruby
@lock = Redis::Lock.new('serialize_stuff', :expiration => 15, :timeout => 0.1)
@lock.lock do
  # do work
end
~~~

This can be especially useful if you're running batch jobs spread across multiple hosts.

Values
------
Simple values are easy as well:

~~~ruby
@value = Redis::Value.new('value_name')
@value.value = 'a'
@value.delete
~~~

Complex data is no problem with :marshal => true:

~~~ruby
@account = Account.create!(params[:account])
@newest  = Redis::Value.new('newest_account', :marshal => true)
@newest.value = @account.attributes
puts @newest.value['username']
~~~

Lists
-----
Lists work just like Ruby arrays:

~~~ruby
@list = Redis::List.new('list_name')
@list << 'a'
@list << 'b'
@list.include? 'c'   # false
@list.values  # ['a','b']
@list << 'c'
@list.delete('c')
@list[0]
@list[0,1]
@list[0..1]
@list.shift
@list.pop
@list.clear
# etc
~~~

You can bound the size of the list to only hold N elements like so:

~~~ruby
# Only holds 10 elements, throws out old ones when you reach :maxlength.
@list = Redis::List.new('list_name', :maxlength => 10)
~~~

Complex data types are serialized with :marshal => true:

~~~ruby
@list = Redis::List.new('list_name', :marshal => true)
@list << {:name => "Nate", :city => "San Diego"}
@list << {:name => "Peter", :city => "Oceanside"}
@list.each do |el|
  puts "#{el[:name]} lives in #{el[:city]}"
end
~~~

Note: If you run into issues, with Marshal errors, refer to the fix in [Issue #176](https://github.com/nateware/redis-objects/issues/176).

Hashes
------
Hashes work like a Ruby [Hash](http://ruby-doc.org/core/classes/Hash.html), with
a few Redis-specific additions.  (The class name is "HashKey" not just "Hash", due to
conflicts with the Ruby core Hash class in other gems.)

~~~ruby
@hash = Redis::HashKey.new('hash_name')
@hash['a'] = 1
@hash['b'] = 2
@hash.each do |k,v|
  puts "#{k} = #{v}"
end
@hash['c'] = 3
puts @hash.all  # {"a"=>"1","b"=>"2","c"=>"3"}
@hash.clear
~~~

Redis also adds incrementing and bulk operations:

~~~ruby
@hash.incr('c', 6)  # 9
@hash.bulk_set('d' => 5, 'e' => 6)
@hash.bulk_get('d','e')  # "5", "6"
~~~

Remember that numbers become strings in Redis.  Unlike with other Redis data types,
`redis-objects` can't guess at your data type in this situation, since you may
actually mean to store "1.5".

Sets
----
Sets work like the Ruby [Set](http://ruby-doc.org/core/classes/Set.html) class.
They are unordered, but guarantee uniqueness of members.

~~~ruby
@set = Redis::Set.new('set_name')
@set << 'a'
@set << 'b'
@set << 'a'  # dup ignored
@set.member? 'c'      # false
@set.members          # ['a','b']
@set.members.reverse  # ['b','a']
@set.each do |member|
  puts member
end
@set.clear
# etc
~~~

You can perform Redis intersections/unions/diffs easily:

~~~ruby
@set1 = Redis::Set.new('set1')
@set2 = Redis::Set.new('set2')
@set3 = Redis::Set.new('set3')
members = @set1 & @set2   # intersection
members = @set1 | @set2   # union
members = @set1 + @set2   # union
members = @set1 ^ @set2   # difference
members = @set1 - @set2   # difference
members = @set1.intersection(@set2, @set3)  # multiple
members = @set1.union(@set2, @set3)         # multiple
members = @set1.difference(@set2, @set3)    # multiple
~~~

Or store them in Redis:

~~~ruby
@set1.interstore('intername', @set2, @set3)
members = @set1.redis.get('intername')
@set1.unionstore('unionname', @set2, @set3)
members = @set1.redis.get('unionname')
@set1.diffstore('diffname', @set2, @set3)
members = @set1.redis.get('diffname')
~~~

And use complex data types too, with :marshal => true:

~~~ruby
@set1 = Redis::Set.new('set1', :marshal => true)
@set2 = Redis::Set.new('set2', :marshal => true)
@set1 << {:name => "Nate",  :city => "San Diego"}
@set1 << {:name => "Peter", :city => "Oceanside"}
@set2 << {:name => "Nate",  :city => "San Diego"}
@set2 << {:name => "Jeff",  :city => "Del Mar"}

@set1 & @set2  # Nate
@set1 - @set2  # Peter
@set1 | @set2  # all 3 people
~~~

Sorted Sets
-----------
Due to their unique properties, Sorted Sets work like a hybrid between
a Hash and an Array.  You assign like a Hash, but retrieve like an Array:

~~~ruby
@sorted_set = Redis::SortedSet.new('number_of_posts')
@sorted_set['Nate']  = 15
@sorted_set['Peter'] = 75
@sorted_set['Jeff']  = 24

# Array access to get sorted order
@sorted_set[0..2]           # => ["Nate", "Jeff", "Peter"]
@sorted_set[0,2]            # => ["Nate", "Jeff"]

@sorted_set['Peter']        # => 75
@sorted_set['Jeff']         # => 24
@sorted_set.score('Jeff')   # same thing (24)

@sorted_set.rank('Peter')   # => 2
@sorted_set.rank('Jeff')    # => 1

@sorted_set.first           # => "Nate"
@sorted_set.last            # => "Peter"
@sorted_set.revrange(0,2)   # => ["Peter", "Jeff", "Nate"]

@sorted_set['Newbie'] = 1
@sorted_set.members         # => ["Newbie", "Nate", "Jeff", "Peter"]
@sorted_set.members.reverse # => ["Peter", "Jeff", "Nate", "Newbie"]

@sorted_set.rangebyscore(10, 100, :limit => 2)   # => ["Nate", "Jeff"]
@sorted_set.members(:with_scores => true)        # => [["Newbie", 1], ["Nate", 16], ["Jeff", 28], ["Peter", 76]]

# atomic increment
@sorted_set.increment('Nate')
@sorted_set.incr('Peter')   # shorthand
@sorted_set.incr('Jeff', 4)
~~~

The other Redis Sorted Set commands are supported as well; see [Sorted Sets API](http://redis.io/commands#sorted_set).

<a name="atomicity"></a>
Atomic Counters and Locks
-------------------------
You are probably not handling atomicity correctly in your app.  For a fun rant
on the topic, see [An Atomic Rant](http://nateware.com/an-atomic-rant.html).

Atomic counters are a good way to handle concurrency:

~~~ruby
@team = Team.find(1)
if @team.drafted_players.increment <= @team.max_players
  # do stuff
  @team.team_players.create!(:player_id => 221)
  @team.active_players.increment
else
  # reset counter state
  @team.drafted_players.decrement
end
~~~

An _atomic block_ gives you a cleaner way to do the above. Exceptions or returning nil
will rewind the counter back to its previous state:

~~~ruby
@team.drafted_players.increment do |val|
  raise Team::TeamFullError if val > @team.max_players  # rewind
  @team.team_players.create!(:player_id => 221)
  @team.active_players.increment
end
~~~

Here's a similar approach, using an if block (failure rewinds counter):

~~~ruby
@team.drafted_players.increment do |val|
  if val <= @team.max_players
    @team.team_players.create!(:player_id => 221)
    @team.active_players.increment
  end
end
~~~

Class methods work too, using the familiar ActiveRecord counter syntax:

~~~ruby
Team.increment_counter :drafted_players, team_id
Team.decrement_counter :drafted_players, team_id, 2
Team.increment_counter :total_online_players  # no ID on global counter
~~~

Class-level atomic blocks can also be used.  This may save a DB fetch, if you have
a record ID and don't need any other attributes from the DB table:

~~~ruby
Team.increment_counter(:drafted_players, team_id) do |val|
  TeamPitcher.create!(:team_id => team_id, :pitcher_id => 181)
  Team.increment_counter(:active_players, team_id)
end
~~~

### Locks ###

Locks work similarly. On completion or exception the lock is released:

~~~ruby
class Team < ActiveRecord::Base
  lock :reorder # declare a lock
end

@team.reorder_lock.lock do
  @team.reorder_all_players
end
~~~

Class-level lock (same concept)

~~~ruby
Team.obtain_lock(:reorder, team_id) do
  Team.reorder_all_players(team_id)
end
~~~

Lock expiration.  Sometimes you want to make sure your locks are cleaned up should
the unthinkable happen (server failure).  You can set lock expirations to handle
this.  Expired locks are released by the next process to attempt lock.  Just
make sure you expiration value is sufficiently large compared to your expected
lock time.

~~~ruby
class Team < ActiveRecord::Base
  lock :reorder, :expiration => 15.minutes
end
~~~

Keep in mind that true locks serialize your entire application at that point.  As
such, atomic counters are strongly preferred.

### Expiration ###

Use :expiration and :expireat options to set default expiration.

~~~ruby
value :value_with_expiration, :expiration => 1.hour
value :value_with_expireat, :expireat => Time.now + 1.hour
~~~

Author
=======
Copyright (c) 2009-2013 [Nate Wiger](http://nateware.com).  All Rights Reserved.
Released under the [Artistic License](http://www.opensource.org/licenses/artistic-license-2.0.php).


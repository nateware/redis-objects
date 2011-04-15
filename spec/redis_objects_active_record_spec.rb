
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'
Redis::Objects.redis = $redis

begin
  require 'active_record'
  ActiveRecord::Base.establish_connection(
    :adapter => 'sqlite3',
    :database => File.expand_path(File.dirname(__FILE__) + '/redis_objects_test.sqlite3')
  )

  class CreatePosts < ActiveRecord::Migration
    def self.up
      create_table :posts do |t|
        t.string :title
        t.string :description, :length => 200
        t.integer :total
        t.timestamps
      end
    end

    def self.down
      drop_table :posts
    end
  end

  CreatePosts.up

  class Post < ActiveRecord::Base
    include Redis::Objects
    counter :total
  end


  describe Redis::Objects do
    it "exercises ActiveRecord in more detail" do
      @ar = Post.new
      @ar.save!
      @ar.destroy

      # @ar.total.reset
      @ar2 = Post.new
      @ar2.save!
      @ar2.total.reset
      @ar2.total.increment.should == 1
      @ar2.id.should == 2
      @ar2.increment(:total).should == 2
      @ar2[:total].should == nil  # DB column
      @ar2.redis.get(@ar2.redis_field_key('total')).to_i.should == 2
      @ar2[:total] = 3  # DB column
      @ar2.total.decrement.should == 1
      @ar2.total.reset
      @ar2.total.should == 0
      @ar2.destroy
    end
  end


  CreatePosts.down


rescue LoadError
  # ActiveRecord not install
  puts "Skipping ActiveRecord tests as active_record is not installed"
end

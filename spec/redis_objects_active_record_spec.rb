
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'
Redis::Objects.redis = $redis

begin
  require 'active_record'
  ActiveRecord::Base.establish_connection(
    :adapter => 'sqlite3',
    :database => File.expand_path(File.dirname(__FILE__) + '/redis_objects_test.sqlite3')
  )

  class CreateBlogs < ActiveRecord::Migration
    def self.up
      create_table :blogs do |t|
        t.string :name
        t.integer :posts_count, :default => 0
        t.timestamps
      end
    end

    def self.down
      drop_table :blogs
    end
  end

  class Blog < ActiveRecord::Base
    include Redis::Objects
    has_many :posts
  end

  class CreatePosts < ActiveRecord::Migration
    def self.up
      create_table :posts do |t|
        t.string :title
        t.string :description, :length => 200
        t.integer :total
        t.integer :blog_id
        t.timestamps
      end
    end

    def self.down
      drop_table :posts
    end
  end

  class Post < ActiveRecord::Base
    include Redis::Objects
    counter :total
    belongs_to :blog, :counter_cache => true
  end


  describe Redis::Objects do
    before do
      CreatePosts.up
      CreateBlogs.up
    end
    after do
      CreatePosts.down
      CreateBlogs.down
    end

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

    it "falls back to ActiveRecord if redis counter is not defined" do
      blog = Blog.create
      blog.reload.posts_count.should == 0
      post = Post.create :blog => blog
      blog.reload.posts_count.should == 1
      blog2 = Blog.create
      Post.create :blog => blog2
      Post.create :blog => blog2
      blog.reload.posts_count.should == 1
      blog2.reload.posts_count.should == 2
      blog.posts_count.should == 1
    end
  end


rescue LoadError
  # ActiveRecord not install
  puts "Skipping ActiveRecord tests as active_record is not installed"
end

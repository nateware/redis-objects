
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'
# $redis used automatically

begin
  require 'active_record'
  ActiveRecord::Base.establish_connection(
    :adapter => 'sqlite3',
    :database => File.expand_path(File.dirname(__FILE__) + '/redis_objects_test.sqlite3')
  )

  # monkey patch to use migrations both in Rails 4.x and 5.x
  class ActiveRecord::Migration
    class << self
      def [](version)
        self
      end
    end
  end unless ActiveRecord::Migration.respond_to?(:[])

  class CreateBlogs < ActiveRecord::Migration[4.2]
    def self.up
      create_table :blogs do |t|
        t.string :name
        # t.integer :num_posts, :default => 0
        t.timestamps null: true
      end
    end

    def self.down
      drop_table :blogs
    end
  end

  class Blog < ActiveRecord::Base
    include Redis::Objects
    has_many :posts
    counter :num_posts
  end

  class CreatePosts < ActiveRecord::Migration[4.2]
    def self.up
      create_table :posts do |t|
        t.string :title
        t.string :description, :length => 200
        t.integer :total
        t.integer :blog_id
        t.timestamps null: true
      end
    end

    def self.down
      drop_table :posts
    end
  end

  class Post < ActiveRecord::Base
    include Redis::Objects
    counter :total
    counter :num_comments
    # Unfortunately, counter counter_cache appears to be broken
    # belongs_to :blog, :counter_cache => :num_posts
    belongs_to :blog
    has_many :comments
  end

  class CreateComments < ActiveRecord::Migration[4.2]
    def self.up
      create_table :comments do |t|
        t.string :body
        t.integer :post_id
        t.timestamps null: true
      end
    end

   def self.down
      drop_table :comments
    end
  end

  class Comment < ActiveRecord::Base
    include Redis::Objects
    belongs_to :post
    # Unfortunately, counter counter_cache appears to be broken
    # belongs_to :post, :counter_cache => :num_comments
  end

  describe ActiveRecord do
    before do
      CreateComments.up
      CreatePosts.up
      CreateBlogs.up
    end
    after do
      CreateComments.down
      CreatePosts.down
      CreateBlogs.down
    end

    it "exercises ActiveRecord in more detail" do
      @ar = Post.new
      should.raise(Redis::Objects::NilObjectId){ @ar.total }
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
      @ar2.total.reset(55)
      @ar2.total.should == 55
      @ar2.total.getset(12).should == 55
      @ar2.total.should == 12
      @ar2.destroy
    end

    it "uses the redis objects counter cache when present" do
      blog = Blog.create
      post = Post.create :blog => blog
      blog.num_posts.incr
      blog.num_posts.should == 1
      Post.counter_defined?(:num_comments).should == true
      post.num_comments.should == 0

      comment = Comment.create :post => post
      post.num_comments.incr
      post.comments.count.should == 1
      post.id.should == 1
      comment.destroy
      blog.num_posts.delete
      blog.destroy
    end

    it "falls back to ActiveRecord if redis counter is not defined" do
      blog = Blog.create
      blog.id.should == 1
      blog.num_posts.should == 0
      post = Post.create :blog => blog
      blog.num_posts.incr
      blog.num_posts.should == 1
      blog2 = Blog.create
      Post.create :blog => blog2
      Post.create :blog => blog2
      blog.reload.num_posts.should == 1
      blog2.num_posts.incr
      blog2.num_posts.incr
      blog2.reload.num_posts.should == 2
      blog.num_posts.should == 1
    end
  end
end

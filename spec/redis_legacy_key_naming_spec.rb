require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'
Redis::Objects.redis = REDIS_HANDLE

require 'securerandom'

require "stringio"

def capture_stderr
  # The output stream must be an IO-like object. In this case we capture it in
  # an in-memory IO object so we can return the string value. You can assign any
  # IO object here.
  previous_stderr, $stderr = $stderr, StringIO.new
  yield
  $stderr.string
ensure
  # Restore the previous value of stderr (typically equal to STDERR).
  $stderr = previous_stderr
end

describe 'Legacy redis key prefix naming compatibility' do
  it 'verifies single level classes work the same' do
    class SingleLevelOne
      include Redis::Objects

      def id
        1
      end
    end

    obj = SingleLevelOne.new
    obj.class.redis_prefix.should == 'single_level_one'
  end

  it 'verifies single level classes obey the legacy naming flag' do
    class SingleLevelTwo
      include Redis::Objects
      self.redis_legacy_naming = true

      def id
        1
      end
    end

    obj = SingleLevelTwo.new
    obj.class.redis_prefix.should == 'single_level_two'
  end

  it 'verifies nested classes do NOT work the same' do
    module Nested
      class NamingOne
        include Redis::Objects
        self.redis_silence_warnings = true
  
        def id
          1
        end
      end
    end

    obj = Nested::NamingOne.new
    obj.class.redis_prefix.should == 'nested__naming_one'
  end

  it 'verifies the legacy naming flag is respected' do
    module Nested
      class NamingTwo
        include Redis::Objects
        self.redis_legacy_naming = true
        self.redis_silence_warnings = true
  
        def id
          1
        end
      end
    end

    Nested::NamingTwo.redis_legacy_naming.should == true
    obj = Nested::NamingTwo.new
    obj.class.redis_prefix.should == 'naming_two'
  end

  it 'verifies that multiple levels respect __ vs _' do
    module NestedLevel
      module Further
        class NamingThree
          include Redis::Objects
          self.redis_silence_warnings = true
    
          def id
            1
          end
        end
      end
    end

    obj = NestedLevel::Further::NamingThree.new
    obj.class.redis_prefix.should == 'nested_level__further__naming_three'
  end

  it 'verifies that multiple levels respect the legacy naming' do
    module NestedLevel
      module Further
        class NamingFour
          include Redis::Objects
          self.redis_legacy_naming = true
    
          def id
            1
          end

          redis_handle = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT, :db => 31)
          value :redis_value, :redis => redis_handle
        end
      end
    end

    NestedLevel::Further::NamingFour.redis_legacy_naming.should == true
    obj = NestedLevel::Further::NamingFour.new
    obj.class.redis_prefix.should == 'naming_four'
    val = SecureRandom.hex(10)
    obj.redis_value = val
    obj.redis_value.should == val
    obj.redis_value.key.should == 'naming_four:1:redis_value'
  end

  it 'verifies that multiple levels do not conflict 1' do
    module NestedLevel
      module Further
        class NamingFive
          include Redis::Objects
          self.redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
          self.redis_silence_warnings = true
    
          def id
            1
          end

          value :redis_value
        end
      end
    end

    obj = NestedLevel::Further::NamingFive.new
    obj.class.redis_prefix.should == 'nested_level__further__naming_five'
    val = SecureRandom.hex(10)
    obj.redis_value = val
    obj.redis_value.should == val
    obj.redis_value.key.should == 'nested_level__further__naming_five:1:redis_value'
    obj.redis_value.redis.should == obj.redis
    obj.redis.get('nested_level__further__naming_five:1:redis_value').should == val
  end

  it 'verifies that multiple levels do not conflict 2' do
    module Nested
      module LevelFurtherNaming
        class Five
          include Redis::Objects
          self.redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
          self.redis_silence_warnings = true
    
          def id
            1
          end

          value :redis_value
        end
      end
    end

    obj = Nested::LevelFurtherNaming::Five.new
    obj.class.redis_prefix.should == 'nested__level_further_naming__five'
    val = SecureRandom.hex(10)
    obj.redis_value = val
    obj.redis_value.should == val
    obj.redis_value.key.should == 'nested__level_further_naming__five:1:redis_value'
    obj.redis.get('nested__level_further_naming__five:1:redis_value').should == val
  end

  it 'verifies that multiple levels do not conflict 3' do
    module Nested
      module LevelFurther
        class NamingFive
          include Redis::Objects
          self.redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
          self.redis_silence_warnings = true
    
          def id
            1
          end

          value :redis_value
        end
      end
    end

    obj = Nested::LevelFurther::NamingFive.new
    obj.class.redis_prefix.should == 'nested__level_further__naming_five'
    val = SecureRandom.hex(10)
    obj.redis_value = val
    obj.redis_value.should == val
    obj.redis_value.key.should == 'nested__level_further__naming_five:1:redis_value'
    obj.redis.get('nested__level_further__naming_five:1:redis_value').should == val
  end

  it 'handles dynamically created classes correctly' do
    module Nested
      class LevelSix
        include Redis::Objects
        self.redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
        self.redis_silence_warnings = true

        def id
          1
        end

        value :redis_value
      end
    end

    obj = Nested::LevelSix.new
    obj.class.redis_prefix.should == 'nested__level_six'
    val = SecureRandom.hex(10)
    obj.redis_value = val
    obj.redis_value.should == val
    obj.redis_value.key.should == 'nested__level_six:1:redis_value'
    obj.redis.get('nested__level_six:1:redis_value').should == val

    DynamicClass = Class.new(Nested::LevelSix)
    DynamicClass.value :redis_value2
    obj2 = DynamicClass.new
    DynamicClass.redis_prefix.should == 'dynamic_class'
    obj2.redis_value.should.be.kind_of(Redis::Value)
    obj2.redis_value2.should.be.kind_of(Redis::Value)
    obj2.redis_value.key.should == 'dynamic_class:1:redis_value'
    obj2.redis_value2.key.should == 'dynamic_class:1:redis_value2'

  end

  it 'handles dynamically created classes correctly in legacy mode' do
    module Nested
      class LevelSeven
        include Redis::Objects
        self.redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
        self.redis_legacy_naming = true

        def id
          1
        end

        value :redis_value
      end
    end

    obj = Nested::LevelSeven.new
    obj.class.redis_prefix.should == 'level_seven'
    val = SecureRandom.hex(10)
    obj.redis_value = val
    obj.redis_value.should == val
    obj.redis_value.key.should == 'level_seven:1:redis_value'
    obj.redis.get('level_seven:1:redis_value').should == val

    DynamicClass2 = Class.new(Nested::LevelSeven)
    DynamicClass2.value :redis_value2
    obj2 = DynamicClass2.new
    DynamicClass2.redis_prefix.should == 'dynamic_class2'
    obj2.redis_value.should.be.kind_of(Redis::Value)
    obj2.redis_value2.should.be.kind_of(Redis::Value)
    obj2.redis_value.key.should == 'dynamic_class2:1:redis_value'
    obj2.redis_value2.key.should == 'dynamic_class2:1:redis_value2'
  end

  it 'prints a warning message if the key name changes' do
    module Nested
      class LevelNine
        include Redis::Objects
        self.redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)

        def id
          1
        end

        value :redis_value
      end
    end

    captured_output = capture_stderr do
      # Does not output anything directly.
      obj = Nested::LevelNine.new
      val = SecureRandom.hex(10)
      obj.redis_value = val
      obj.redis_value.should == val
    end

    captured_output.should =~ /Warning:/i
  end

  it 'supports a method to migrate legacy key names' do
    module Nested
      class Legacy
        include Redis::Objects
        self.redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
        self.redis_legacy_naming = true

        # override this for testing - need two classes as if we imagine an old and new one
        # also use the legacy flat prefix that ignores the nested class name
        self.redis_prefix = 'modern'

        def initialize(id)
          @id = id
        end
        def id
          @id
        end

        value :redis_value
        counter :redis_counter
        hash_key :redis_hash
        list :redis_list
        set :redis_set
        sorted_set :redis_sorted_set

        # global class counters
        value :global_value, :global => true
        counter :global_counter, :global => true
        hash_key :global_hash_key, :global => true
        list :global_list, :global => true
        set :global_set, :global => true
        sorted_set :global_sorted_set, :global => true
      
        #callable as key
        value :global_proc_value, :global => true, :key => Proc.new { |roster| "#{roster.name}:#{Time.now.strftime('%Y-%m-%dT%H')}:daily" }
      end
    end

    module Nested
      class Modern
        include Redis::Objects
        self.redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)

        def initialize(id)
          @id = id
        end
        def id
          @id
        end

        value :redis_value
        counter :redis_counter
        hash_key :redis_hash
        list :redis_list
        set :redis_set
        sorted_set :redis_sorted_set

        # global class counters
        value :global_value, :global => true
        counter :global_counter, :global => true
        hash_key :global_hash_key, :global => true
        list :global_list, :global => true
        set :global_set, :global => true
        sorted_set :global_sorted_set, :global => true
      
        #callable as key
        value :global_proc_value, :global => true, :key => Proc.new { |roster| "#{roster.name}:#{Time.now.strftime('%Y-%m-%dT%H')}:daily" }
      end
    end

    # Iterate over them
    Nested::Modern.redis_objects.length.should == 13
    Nested::Modern.redis_objects.length.should == Nested::Legacy.redis_objects.length.should
    Nested::Legacy.redis_prefix.should == 'modern'
    Nested::Modern.redis_prefix.should == 'nested__modern'

    # Create a whole bunch of keys using the legacy names
    30.times do |i|
      # warn i.inspect
      obj = Nested::Legacy.new(i)
      obj.redis_value = i
      obj.redis_value.to_i.should == i
      obj.redis_counter.increment
      obj.redis_hash[:key] = i
      obj.redis_list << i
      obj.redis_set << i
      obj.redis_sorted_set[i] = i
    end

    obj = Nested::Legacy.new(99)
    obj.global_value = 42
    obj.global_counter.increment
    obj.global_counter.increment
    obj.global_counter.increment
    obj.global_hash_key[:key] = 'value'
    obj.global_set << 'a' << 'b'
    obj.global_sorted_set[:key] = 2.2

    Nested::Modern.migrate_redis_legacy_keys

    # Try to access the keys through modern names now
    30.times do |i|
      # warn i.inspect
      obj = Nested::Modern.new(i)
      obj.redis_value.to_i.should == i
      obj.redis_counter.to_i.should == 1
      obj.redis_hash[:key].to_i.should == i
      obj.redis_list[0].to_i.should == i
      obj.redis_set.include?(i).should == true
      obj.redis_sorted_set[i].should == i
    end

    obj = Nested::Modern.new(99)
    obj.global_value.to_i.should == 42
    obj.global_counter.to_i.should == 3
    obj.global_hash_key[:key].should == 'value'
    obj.global_set.should.include?('a').should == true
    obj.global_set.should.include?('b').should == true
    obj.global_sorted_set[:key].should == 2.2
  end
end

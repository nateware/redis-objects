
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'

class CustomSerializer
  class << self
    attr_accessor :dump_called, :load_called, :dump_args, :load_args
  end

  def self.dump(value, *args, **kargs)
    @dump_called = true
    @dump_args = [args, kargs]
    Marshal.dump(value)
  end

  def self.load(value, *args, **kargs)
    @load_called = true
    @load_args = [args, kargs]
    Marshal.load(value)
  end

  def self.reset!
    @dump_called = nil
    @load_called = nil
  end
end

describe 'with custom serialization' do
  before do
    CustomSerializer.reset!
  end

  describe Redis::Value do
    before do
      @value = Redis::Value.new(
        'spec/value_custom_serializer',
        marshal: true,
        serializer: CustomSerializer
      )
      @value.clear
    end

    it 'uses custom serializer' do
      @value.value = { json: 'data' }
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == nil
      @value.value.should == { json: 'data' }
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == true
    end

    it 'passes extra arguments to dump' do
      @value.options[:marshal_dump_args] = ['some', { extra: 'arguments' }]
      @value.value = 1
      CustomSerializer.dump_args.should == [['some'], { extra: 'arguments' }]
    end

    it 'passes extra arguments to load' do
      @value.options[:marshal_load_args] = ['some', { extra: 'arguments' }]
      @value.value = 1
      @value.value.should == 1
      CustomSerializer.load_args.should == [['some'], { extra: 'arguments' }]
    end
  end

  describe Redis::List do
    before do
      @list = Redis::List.new(
        'spec/list_custom_serializer',
        marshal: true,
        serializer: CustomSerializer
      )
      @list.clear
    end

    it 'uses custom serializer' do
      @list << { json: 'data' }
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == nil
      @list.should == [{ json: 'data' }]
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == true
    end

    it 'passes extra arguments to dump' do
      @list.options[:marshal_dump_args] = ['some', { extra: 'arguments' }]
      @list << 1
      CustomSerializer.dump_args.should == [['some'], { extra: 'arguments' }]
    end

    it 'passes extra arguments to load' do
      @list.options[:marshal_load_args] = ['some', { extra: 'arguments' }]
      @list << 1
      @list.values.should == [1]
      CustomSerializer.load_args.should == [['some'], { extra: 'arguments' }]
    end
  end

  describe Redis::HashKey do
    before do
      @hash = Redis::HashKey.new(
        'spec/hash_custom_serializer',
        marshal: true,
        serializer: CustomSerializer
      )
      @hash.clear
    end

    it 'uses custom serializer' do
      @hash['a'] = 1
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == nil
      @hash.value.should == { 'a' => 1 }
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == true
    end

    it 'passes extra arguments to dump' do
      @hash.options[:marshal_dump_args] = ['some', { extra: 'arguments' }]
      @hash['a'] = 1
      CustomSerializer.dump_args.should == [['some'], { extra: 'arguments' }]
    end

    it 'passes extra arguments to load' do
      @hash.options[:marshal_load_args] = ['some', { extra: 'arguments' }]
      @hash['a'] = 1
      @hash.value.should == { 'a' => 1 }
      CustomSerializer.load_args.should == [['some'], { extra: 'arguments' }]
    end
  end

  describe Redis::Set do
    before do
      @set = Redis::Set.new(
        'spec/set_custom_serializer',
        marshal: true,
        serializer: CustomSerializer
      )
      @set.clear
    end

    it 'uses custom serializer' do
      @set << 'a'
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == nil
      @set.members.should == ['a']
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == true
    end

    it 'passes extra arguments to dump' do
      @set.options[:marshal_dump_args] = ['some', { extra: 'arguments' }]
      @set << 'a'
      CustomSerializer.dump_args.should == [['some'], { extra: 'arguments' }]
    end

    it 'passes extra arguments to load' do
      @set.options[:marshal_load_args] = ['some', { extra: 'arguments' }]
      @set << 'a'
      @set.members.should == ['a']
      CustomSerializer.load_args.should == [['some'], { extra: 'arguments' }]
    end
  end

  describe Redis::SortedSet do
    before do
      @set = Redis::SortedSet.new(
        'spec/zset_custom_serializer',
        marshal: true,
        serializer: CustomSerializer
      )
      @set.clear
    end

    it 'uses custom serializer' do
      @set['a'] = 1
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == nil
      @set.members.should == ['a']
      CustomSerializer.dump_called.should == true
      CustomSerializer.load_called.should == true
    end

    it 'passes extra arguments to dump' do
      @set.options[:marshal_dump_args] = ['some', { extra: 'arguments' }]
      @set['a'] = 1
      CustomSerializer.dump_args.should == [['some'], { extra: 'arguments' }]
    end

    it 'passes extra arguments to load' do
      @set.options[:marshal_load_args] = ['some', { extra: 'arguments' }]
      @set['a'] = 1
      @set.members.should == ['a']
      CustomSerializer.load_args.should == [['some'], { extra: 'arguments' }]
    end
  end
end

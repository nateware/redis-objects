require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../../redis-namespace/lib')
require 'redis/namespace'

describe 'Redis::Namespace compat' do
  it "tests the compatibility of Hash and ::Hash conflicts" do
    ns = Redis::Namespace.new("resque")
    ns.instance_eval { rem_namespace({"resque:x" => nil}) }.should == {"x"=>nil}
    class Foo
      include Redis::Objects
    end
    ns.instance_eval { rem_namespace({"resque:x" => nil}) }.should == {"x"=>nil}
  end
end

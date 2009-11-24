# This is the class loader, for use as "include Redis::Objects::Sets"
# For the object itself, see "Redis::Set"
require 'redis/set'
class Redis
  module Objects
    module Sets
    end
  end
end
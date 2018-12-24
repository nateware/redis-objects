require File.dirname(__FILE__) + '/base_object'

class Redis
  #
  # Class representing a Redis enumerable type (list, set, sorted set, or hash).
  #
  class EnumerableObject < BaseObject
    include Enumerable

    # Iterate through each member. Redis::Objects mixes in Enumerable,
    # so you can also use familiar methods like +collect+, +detect+, and so forth.
    def each(&block)
      value.each(&block)
    end

    def sort(options={})
      return super() if block_given?
      options[:order] = "asc alpha" if options.keys.count == 0  # compat with Ruby
      val = redis.sort(key, options)
      val.is_a?(Array) ? val.map{|v| unmarshal(v)} : val
    end

    # ActiveSupport's core extension `Enumerable#as_json` implementation is incompatible with ours.
    def as_json(*)
      to_hash
    end
  end
end

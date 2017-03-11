# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis/objects/version'

Gem::Specification.new do |spec|
  spec.name          = "redis-objects"
  spec.version       = Redis::Objects::VERSION
  spec.authors       = ["Nate Wiger"]
  spec.email         = ["nwiger@gmail.com"]
  spec.description   = %q{Map Redis types directly to Ruby objects. Works with any class or ORM.}
  spec.summary       = %q{Map Redis types directly to Ruby objects}
  spec.homepage      = "http://github.com/nateware/redis-objects"
  spec.license       = 'Artistic-2.0'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "redis", "~> 3.3"

  spec.add_development_dependency "bundler", "~> 1.14"
  # spec.add_development_dependency "rspec", "~> 3.5" # Jul 2016
  spec.add_development_dependency "bacon", "~> 1.2" # Dec 2012
  spec.add_development_dependency "connection_pool", "~> 2.2" # Nov 2016

  # compatibility testing
  spec.add_development_dependency "redis-namespace", "~> 1.5" # Feb 2017
  spec.add_development_dependency "activerecord", "~> 5.0" # Mar 2017
end

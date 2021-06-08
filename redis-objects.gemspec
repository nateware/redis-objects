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

  # Only fix this one version or else tests break
  spec.add_dependency "redis", "~> 4.2"

  # Ignore gemspec warnings on these.  Trying to fix them to versions breaks TravisCI
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "bacon"
  spec.add_development_dependency "connection_pool"

  # Compatibility testing
  spec.add_development_dependency "redis-namespace"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "sqlite3"
end

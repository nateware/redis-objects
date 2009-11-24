spec = Gem::Specification.new do |s|
  s.name = 'redis-atoms'
  s.version = '0.1.0'
  s.summary = "Atomic counters and operations using Redis"
  s.description = %{Redis::Atoms is a lightweight library that can be used with any class to add support for atomic counters and operations}
  s.files = Dir['lib/**/*.rb'] + Dir['spec/**/*.rb']
  s.require_path = 'lib'
  s.autorequire = 'redis/atoms'
  s.has_rdoc = true
  s.extra_rdoc_files = Dir['[A-Z]*']
  s.rdoc_options << '--title' <<  'Redis::Atoms -- Atomic counters and operations using Redis'
  s.author = "Nate Wiger"
  s.email = "nate@wiger.org"
  s.homepage = "http://github.com/nateware/redis-atoms"
end

spec = Gem::Specification.new do |s|
  s.name = 'redis-objects'
  s.version = '0.1.0'
  s.summary = "Lightweight map of Redis types to Ruby objects"
  s.description = %{Redis::Objects is a lightweight library that lets you use Redis primitives as Ruby objects from any class or ORM}
  s.files = Dir['lib/**/*.rb'] + Dir['spec/**/*.rb']
  s.require_path = 'lib'
  #s.autorequire = 'redis/objects'
  s.has_rdoc = true
  s.rubyforge_project = 'redis-objects'
  s.extra_rdoc_files = Dir['[A-Z]*']
  s.rdoc_options << '--title' <<  'Redis::Objects -- Use Redis types as Ruby objects'
  s.author = "Nate Wiger"
  s.email = "nate@wiger.org"
  s.homepage = "http://github.com/nateware/redis-objects"
end

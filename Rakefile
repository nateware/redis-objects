require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "redis-objects"
    gem.summary = %Q{Map Redis types directly to Ruby objects}
    gem.description = %Q{Map Redis types directly to Ruby objects. Works with any class or ORM.}
    gem.email = "nate@wiger.org"
    gem.homepage = "http://github.com/nateware/redis-objects"
    gem.authors = ["Nate Wiger"]
    gem.add_development_dependency "bacon", ">= 0"
    gem.add_development_dependency "redis-namespace", ">= 1.2.0"
    #gem.requirements << 'redis, v3.0.2 or greater'
    #gem.add_dependency('redis', '>= 3.0.2')  # ALSO: update spec/spec_helper.rb
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

# require 'rdoc/task'
# Rake::TestTask.new(:spec) do |spec|
#   spec.libs << 'lib' << 'spec'
#   spec.pattern = 'spec/**/*_spec.rb'
#   spec.verbose = true
# end

desc "run all the specs"
task :test do
  sh "bundle exec bacon spec/*_spec.rb"
end


begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |spec|
    spec.libs << 'spec'
    spec.pattern = 'spec/**/*_spec.rb'
    spec.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :spec => :check_dependencies

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "Redis::Objects #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

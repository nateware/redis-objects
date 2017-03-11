require "bundler/gem_tasks"

desc "run all the specs"
task :test do
  sh "bacon spec/*_spec.rb"
end
task :default => :test
task :spec => :test

desc "show changelog"
task :changelog do
  latest = `git tag |tail -1`.chomp
  sh "git log --pretty=format:'* %s %b [%an]' #{latest}..HEAD"
end

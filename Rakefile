
task :test do
  base = File.dirname(__FILE__)
  Dir[base + '/spec/*_spec.rb'].each do |f|
    sh "ruby #{f}"
  end
end
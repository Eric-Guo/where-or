begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end
require 'bundler/gem_tasks'

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.ruby_opts = ['-r./test/where-or.rb']
  t.verbose = true
end

task default: :test
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << "spec"
  t.warning = false
  t.test_files = FileList['spec/**/*_spec.rb']
end

task :default => :test

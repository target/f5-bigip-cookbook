require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'foodcritic'

# Style tests. Rubocop and Foodcritic
namespace :style do
  desc 'Run Ruby style checks'
  task :ruby do
    sh 'rubocop'
  end

  desc 'Run Chef style checks'
  FoodCritic::Rake::LintTask.new(:chef) do |t|
    t.options = {
      :fail_tags => ['any', '~FC015']
    }
  end
end

desc 'Run all style checks'
task :style => ['style:chef', 'style:ruby']

# Rspec and ChefSpec
desc 'Run ChefSpec examples'
RSpec::Core::RakeTask.new(:spec)

# Integration tests. Kitchen.ci
namespace :integration do
  desc 'Run Vagrant'
  task :vagrant do
    sh 'vagrant destroy -f'
    sh 'vagrant up'
    sh 'vagrant provision admin'
  end
end

desc 'Run all tests on Jenkins'
task :jenkins => ['style', 'spec']

# Default
task :default => ['style', 'spec']

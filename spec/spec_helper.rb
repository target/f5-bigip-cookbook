require 'bundler/setup'
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/test/'
end

require 'chefspec'
require 'chefspec/berkshelf'
require 'f5-icontrol'

# Add libraries to our LOAD_PATH
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'libraries'))

# Require all our libraries
require "#{File.join(File.dirname(__FILE__), '..', 'libraries')}/helpers.rb"
require "#{File.join(File.dirname(__FILE__), '..', 'libraries')}/loader.rb"
require "#{File.join(File.dirname(__FILE__), '..', 'libraries')}/load_balancer.rb"
Dir["#{File.join(File.dirname(__FILE__), '..', 'libraries')}/resource_*.rb"].each { |f| require File.expand_path(f) }
Dir["#{File.join(File.dirname(__FILE__), '..', 'libraries')}/provider_*.rb"].each { |f| require File.expand_path(f) }

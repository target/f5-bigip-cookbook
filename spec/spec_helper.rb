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
Dir["#{File.join(File.dirname(__FILE__), '..', 'libraries')}/*.rb"].each { |f| require File.expand_path(f) }

at_exit { ChefSpec::Coverage.report! }

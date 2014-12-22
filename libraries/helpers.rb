#
# Cookbook Name:: f5-bigip
# Library:: helpers
#
# Copyright 2014, Target Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module F5
  # Helper functions for f5 cookbook
  module Helpers
    # Adding chef_vault_item from chef-vault here as chef_vault_item
    # is normally only exposed to Recipe Class and I want to use in
    # Provider Class
    # TD: Figure out if there is a way to actually use chef_vault_item
    # From chef-vault cookbook in providers
    def chef_vault_item(bag, item)
      begin
        require 'chef-vault'
      rescue LoadError
        Chef::Log.warn("Missing gem 'chef-vault', use recipe[chef-vault] to install it first.")
      end

      if node['dev_mode']
        Chef::DataBagItem.load(bag, item)
      else
        ChefVault::Item.load(bag, item)
      end
    end

    # Returns a Hash from a SOAP::Mapping::Object. All 'key/value' pairs'
    # within a SOAP::Mapping::Object are coerced to real Hash key/value pairs.
    # Will dig deep when Arrays and traverse embedded Arrays and
    # other SOAP::Mapping::Object.
    #
    # @param obj [Object] the soap mapping to be processed. While intended for
    #   SOAP::Mapping::Object, this method safely processes arbitrary objects
    # @return [Object] a Hash representing the SOAP::Mapping::Object
    def self.soap_mapping_to_hash(obj) # rubocop:disable MethodLength
      if obj.is_a?(::SOAP::Mapping::Object)
        h = {}
        obj.__xmlele.each do |ele|
          value = ele.last
          value = soap_mapping_to_hash(value) if value.is_a?(::SOAP::Mapping::Object)
          h[ele.first.name] = value
        end
        h
      elsif obj.is_a?(Array)
        obj.each_with_object([]) { |e, a| a << soap_mapping_to_hash(e) }
      else
        obj
      end
    end

    #
    # Check that key exists in hash and that it's not nil
    #
    # @param [Hash] hash
    #   the Hash to check
    # @param [String, Symbol] key
    #   the key to check the hash with
    #
    # @return [TrueClass, FalseClass]
    #   true if key exists and not nil, false otherwise
    #
    def check_key_nil(hash, key)
      return false unless hash.key? key
      !hash[key].nil?
    end
  end
end

Chef::Provider.send(:include, ::F5::Helpers)
Chef::Resource.send(:include, ::F5::Helpers)

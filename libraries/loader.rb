#
# Cookbook Name:: f5-bigip
# Library:: loader
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
  # rubocop:disable ClassVars, MethodLength
  # Loader function to load data from f5 to compare resources to
  module Loader
    include F5::Helpers

    #
    # Convert to Array
    #
    # @param [Object] item to make sure is an Array
    #
    # @return [Array] if obj was already an Array it returns the obj.  Otherwise
    #   returns a single element Array of the obj
    #
    def convert_to_array(obj)
      obj = [obj] unless obj.is_a? Array
      obj
    end

    # Method call to require f5-icontrol
    # after chef_gem has had a chance to run
    def load_dependencies
      require 'f5-icontrol'
    end

    #
    # Interfaces to load from F5 icontrol
    #
    # @return [Array<String>] list of interfaces to load from F5 icontrol
    #
    def interfaces
      [
        'System.Session',
        'LocalLB.Monitor',
        'LocalLB.NodeAddressV2',
        'LocalLB.Pool',
        'LocalLB.VirtualServer',
        'LocalLB.Class',
        'LocalLB.Rule',
        'Management.DeviceGroup',
        'Management.KeyCertificate',
        'System.ConfigSync',
        'System.Failover',
        'System.Inet'
      ]
    end

    #
    # Retrieve/Create load balancer from list of load balancers for a resource
    #
    # @return [F5::LoadBalancer] instance of F5::LoadBalancer matching the resource
    #
    def load_balancer # rubocop:disable AbcSize
      raise 'Can not determine hostname to load client for' if @new_resource.f5.nil?
      @@load_balancers ||= []
      add_lb(@new_resource.f5) if @@load_balancers.empty?
      add_lb(@new_resource.f5) if @@load_balancers.find { |lb| lb.name == @new_resource.f5 }.nil?
      @@load_balancers.find { |lb| lb.name == @new_resource.f5 }
    end

    #
    # Add new load balancer to list of load balancers
    #
    # @param hostname [String] hostname of load balancer to add
    #
    def add_lb(hostname)
      @@load_balancers << LoadBalancer.new(hostname, create_icontrol(hostname))
    end

    #
    # Create icontrol binding for load balancer
    #
    # @param hostname [String] hostname of load balancer to create binding for
    #
    # @return [Hash] Hash of interfaces from F5::IControl
    #
    def create_icontrol(hostname) # rubocop:disable AbcSize
      load_dependencies
      f5_creds = chef_vault_item(node['f5-bigip']['credentials']['databag'], node['f5-bigip']['credentials']['item'])
      if node['f5-bigip']['credentials']['host_is_key']
        f5_creds = f5_creds[hostname]
      else
        f5_creds = f5_creds[node['f5-bigip']['credentials']['key']] unless node['f5-bigip']['credentials']['key'].empty?
      end
      F5::IControl.new(hostname,
                       f5_creds['username'],
                       f5_creds['password'],
                       interfaces).get_interfaces
    end
  end
end

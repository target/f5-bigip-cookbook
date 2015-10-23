#
# Cookbook Name:: f5-bigip
# Library:: F5::LoadBalancer::Ltm
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

require 'load_balancer/ltm/monitors'
require 'load_balancer/ltm/pools'
require 'load_balancer/ltm/virtual_servers'

module F5
  class LoadBalancer
    # Class representing resources in a Local Traffic Manager
    class Ltm
      attr_reader :client

      def initialize(client)
        @client = client
      end

      def nodes # rubocop:disable MethodLength
        @nodes ||= begin
          node_list = client['LocalLB.NodeAddressV2'].get_list

          # Check if empty
          return [] if node_list.empty?

          addresses = client['LocalLB.NodeAddressV2'].get_address(node_list)
          statuses = client['LocalLB.NodeAddressV2'].get_object_status(node_list)

          states = statuses.map { |status| status['enabled_status'] != 'ENABLED_STATUS_DISABLED' }

          node_list.each_with_index.map do |node, index|
            { 'name' => node, 'address' => addresses[index], 'enabled' => states[index] }
          end
        end
      end

      def pools
        @pools ||= F5::LoadBalancer::Ltm::Pools.new(client)
      end

      def virtual_servers
        @virtual_servers ||= F5::LoadBalancer::Ltm::VirtualServers.new(client)
      end

      def monitors
        @monitors ||= F5::LoadBalancer::Ltm::Monitors.new(client)
      end
    end
  end
end

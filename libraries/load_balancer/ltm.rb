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
        @nodes = []
        node_list = {}
        partitions = client['Management.Partition'].get_partition_list
        partitions.each do |partition|
          node_list[partition['partition_name']] = client['LocalLB.NodeAddressV2'].get_list
          next if node_list[partition['partition_name']].empty?

          addresses = client['LocalLB.NodeAddressV2'].get_address(node_list[partition['partition_name']])
          statuses = client['LocalLB.NodeAddressV2'].get_object_status(node_list[partition['partition_name']])
          states = statuses.map { |status| status['enabled_status'] != 'ENABLED_STATUS_DISABLED' }

          node_list[partition['partition_name']].each_with_index.map do |node, index|
            @nodes << { 'name' => node, 'address' => addresses[index], 'enabled' => states[index], 'partition' => partition['partition_name'] }
          end
        end
        return @nodes
      end

      def partitions
        client['Management.Partition'].get_partition_list.each do |p|
          parts << p['partition_name']
        end
        @partitions ||= parts
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

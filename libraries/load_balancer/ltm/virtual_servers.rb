#
# Cookbook Name:: f5-bigip
# Library:: F5::LoadBalancer::Ltm::VirtualServers
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

require 'load_balancer/ltm/virtual_servers/virtual_server'
require 'forwardable'

module F5
  class LoadBalancer
    class Ltm
      # A collection of virtual servers.  This Class is an interface for sending bulk
      # updates to F5 for multiple items in a single API call.
      class VirtualServers
        include F5::Helpers
        include ::Enumerable
        extend ::Forwardable

        def_delegators :@virtual_servers, :find

        def initialize(client)
          @client = client
          refresh_all
        end

        #
        # The names of all the monitors
        #
        def names
          @virtual_servers.map { |v| v.name }
        end

        #
        # Dump data of all loaded virtual servers
        #
        def all
          @virtual_servers
        end

        def refresh_destination_address
          destination_addresses = @client['LocalLB.VirtualServer'].get_destination_v2(names)

          @virtual_servers.each_with_index do |vs, idx|
            vs.destination_address = destination_addresses[idx]['address']
            vs.destination_port = destination_addresses[idx]['port']
          end
        end

        def refresh_destination_wildmask
          wildmasks = @client['LocalLB.VirtualServer'].get_wildmask(names)

          @virtual_servers.each_with_index do |vs, idx|
            vs.destination_wildmask = wildmasks[idx]
          end
        end

        def refresh_type
          refresh('type')
        end

        def refresh_protocol
          refresh('protocol')
        end

        def refresh_default_pool
          default_pools = @client['LocalLB.VirtualServer'].get_default_pool_name(names)

          @virtual_servers.each_with_index do |vs, idx|
            vs.default_pool = default_pools[idx]
          end
        end

        def refresh_status
          statuses = @client['LocalLB.VirtualServer'].get_object_status(names)

          @virtual_servers.each_with_index do |vs, idx|
            vs.status = statuses[idx]
          end
        end

        def refresh_profiles
          profiles = @client['LocalLB.VirtualServer'].get_profile(names)

          @virtual_servers.each_with_index do |vs, idx|
            vs.profiles = F5::Helpers.soap_mapping_to_hash(profiles[idx])
                          .each { |p| p.delete('profile_type') }
          end
        end

        def refresh_vlans
          vlans = @client['LocalLB.VirtualServer'].get_vlan(names)

          @virtual_servers.each_with_index do |vs, idx|
            vs.vlans = F5::Helpers.soap_mapping_to_hash(vlans[idx])
          end
        end

        def refresh_snat
          refresh('source_address_translation_type', 'snat_type')
          refresh('source_address_translation_snat_pool', 'snat_pool')
        end

        def refresh_persistence
          persistence_profiles = @client['LocalLB.VirtualServer']
                                 .get_persistence_profile(names)

          @virtual_servers.each_with_index do |vs, idx|
            vs.default_persistence_profile = F5::Helpers.soap_mapping_to_hash(persistence_profiles[idx])
          end

          refresh('fallback_persistence_profile')
        end

        def refresh_rules
          refresh('rule', 'rules')
        end

        private

        def refresh_all
          @virtual_servers = @client['LocalLB.VirtualServer']
                             .get_list.map { |v| F5::LoadBalancer::Ltm::VirtualServers::VirtualServer.new(v) }
          %w(destination_wildmask destination_address type default_pool protocol
             profiles status vlans snat persistence rules).each do |item|
            send("refresh_#{item}")
          end
        end

        def refresh(key, item = nil)
          item = key if item.nil?

          values = @client['LocalLB.VirtualServer'].send("get_#{key}", names)

          @virtual_servers.each_with_index do |vs, idx|
            vs.send("#{item}=", values[idx])
          end
        end
      end
    end
  end
end

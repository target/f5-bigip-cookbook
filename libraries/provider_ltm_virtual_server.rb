#
# Author:: Jacob McCann (<jacob.mccann2@target.com>)
# Cookbook Name:: f5-bigip
# Provider:: ltm_virtual_server
#
# Copyright:: 2013, Target Corporation
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

class Chef
  class Provider
    #
    # Chef Provider for F5 LTM Virtual Server
    #
    class F5LtmVirtualServer < Chef::Provider
      include F5::Loader

      # Support whyrun
      def whyrun_supported?
        false
      end

      def load_current_resource # rubocop:disable MethodLength, AbcSize
        @current_resource = Chef::Resource::F5LtmVirtualServer.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.vs_name(@new_resource.vs_name)
        @current_resource.default_persistence_profile_cnt = 0

        # Check if virtual server exists
        vs = load_balancer.ltm.virtual_servers.find { |v| v.name =~ %r{(^|\/)#{@new_resource.vs_name}$} }

        @current_resource.exists = !vs.nil?
        return @current_resource unless @current_resource.exists

        @current_resource.default_persistence_profile_cnt = vs.default_persistence_profile.size

        @current_resource.destination_address(vs.destination_address.gsub('/Common/', ''))
        @current_resource.destination_port(vs.destination_port)
        @current_resource.destination_wildmask(vs.destination_wildmask)
        @current_resource.type(vs.type)
        @current_resource.default_pool(vs.default_pool.gsub('/Common/', ''))
        @current_resource.vlan_state(vs.vlans['state'])
        @current_resource.vlans(vs.vlans['vlans'].map { |v| v.gsub('/Common/', '') })
        @current_resource.enabled(vs.enabled)
        @current_resource.profiles(vs.profiles)
        @current_resource.snat_type(vs.snat_type)
        @current_resource.snat_pool(vs.snat_pool)
        if vs.default_persistence_profile.empty?
          @current_resource.default_persistence_profile(nil)
        else
          @current_resource.default_persistence_profile(vs.default_persistence_profile.first['profile_name'])
        end
        @current_resource.fallback_persistence_profile(vs.fallback_persistence_profile)
        @current_resource.rules(vs.rules)

        @current_resource
      end

      #
      # Create action for f5_icontrol_virtual_server provider
      #
      def action_create # rubocop:disable CyclomaticComplexity, MethodLength, AbcSize, PerceivedComplexity
        create_virtual_server unless current_resource.exists

        set_default_pool unless match?('default_pool')

        set_destination_wildmask unless match?('destination_wildmask')
        set_destination_address_port unless match?('destination_address')
        set_destination_address_port unless match?('destination_port')

        remove_all_rules unless match?('rules') && match?('profiles')
        remove_profiles unless match?('profiles')

        set_enabled_state unless match?('enabled')

        update_vlans unless match?('vlans')
        update_vlans unless match?('vlan_state')

        update_snat unless match?('snat_type')
        update_snat unless match?('snat_pool')

        update_default_persistence_profile if current_resource.default_persistence_profile_cnt > 1
        update_default_persistence_profile unless match?('default_persistence_profile')
        update_fallback_persistence_profile(new_resource.fallback_persistence_profile) unless match?('fallback_persistence_profile')

        add_profiles unless match?('profiles')
        add_rules unless match?('rules')
      end

      #
      # Delete action for f5_icontrol_virtual_server provider
      #
      def action_delete
        delete_virtual_server if @current_resource.exists
      end

      private

      #
      # Method to check if for given attribute that current and new resources match
      #
      # @return TrueClass, FalseClass
      #
      def match?(attr)
        current_val = current_resource.send(attr)
        new_val = new_resource.send(attr)

        # We convert to strings here in case there is a type mismatch
        # Example: `destination_port` passed as a String but F5 returns FixNum
        return true if current_val.to_s == new_val.to_s

        # Order matters on rules so we cannot do length or intersection check
        if current_val.is_a?(Array) && new_val.is_a?(Array) && attr != 'rules'
          content_match = (current_val & new_val).eql?(current_val)
          return content_match && current_val.length == new_val.length
        end

        false
      end

      #
      # Create a new virtual server given new_resource attributes
      #
      def create_virtual_server # rubocop:disable AbcSize, MethodLength
        converge_by("Create #{new_resource}") do
          Chef::Log.info("Create #{new_resource}")
          load_balancer.client['LocalLB.VirtualServer']
            .create new_virtual_server_defenition, [new_resource.destination_wildmask],
                    new_virtual_server_resource, [new_resource.profiles]
          update_current_resource(%w(destination_address destination_port protocol
                                     destination_wildmask type default_pool profiles))
          current_resource.default_persistence_profile_cnt = 0
          current_resource.enabled(true)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set virtual server default pool based on new_resource default_pool parameter
      #
      def set_default_pool # rubocop:disable AbcSize
        converge_by("Updating #{new_resource} default pool to #{new_resource.default_pool}") do
          Chef::Log.info("Updating #{new_resource} default pool to #{new_resource.default_pool}")
          load_balancer.client['LocalLB.VirtualServer'].set_default_pool_name([new_resource.vs_name], [new_resource.default_pool])
          current_resource.default_pool(new_resource.default_pool)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set virtual server wildmask based on new_resource wildmask parameter
      #
      def set_destination_wildmask # rubocop:disable AbcSize
        converge_by("Updating #{new_resource} destination wildmask to #{new_resource.destination_wildmask}") do
          Chef::Log.info("Updating #{new_resource} destination wildmask to #{new_resource.destination_wildmask}")
          load_balancer.client['LocalLB.VirtualServer'].set_wildmask([new_resource.vs_name], [new_resource.destination_wildmask])
          current_resource.destination_wildmask(new_resource.destination_wildmask)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set virtual server destination address/port given new_resource parameters
      #
      def set_destination_address_port # rubocop:disable AbcSize
        converge_by("Updating #{new_resource} destination address to #{new_resource.destination_address}:#{new_resource.destination_port}") do
          Chef::Log.info("Updating #{new_resource} destination address to #{new_resource.destination_address}:#{new_resource.destination_port}")
          load_balancer.client['LocalLB.VirtualServer'].set_destination_v2(
            [new_resource.vs_name],
            [{ 'address' => new_resource.destination_address, 'port' => new_resource.destination_port }]
          )
          update_current_resource(%w(destination_address destination_port))

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set whether virtual server is enabled/disabled based on new_resource enabled parameter
      #
      def set_enabled_state
        converge_by("#{enabled_state_message} #{new_resource}") do
          Chef::Log.info("#{enabled_state_message} #{new_resource}")
          load_balancer.client['LocalLB.VirtualServer'].set_enabled_state([new_resource.vs_name], [enabled_state])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Add any missing profiles associated with current_resource
      #
      def add_profiles # rubocop:disable AbcSize
        matching_profiles = new_resource.profiles & current_resource.profiles
        missing_profiles = new_resource.profiles - matching_profiles

        return if missing_profiles.empty?

        converge_by("Adding profiles to #{new_resource}") do
          Chef::Log.info("Adding profiles to #{new_resource}")
          load_balancer.client['LocalLB.VirtualServer'].add_profile([new_resource.vs_name], [missing_profiles])
          current_resource.profiles(new_resource.profiles)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Remove any extra profiles associated with current_resource that shouldn't be
      #
      def remove_profiles # rubocop:disable AbcSize
        matching_profiles = new_resource.profiles & current_resource.profiles
        extra_profiles = current_resource.profiles - matching_profiles

        return if extra_profiles.empty?

        converge_by("Removing profiles from #{new_resource}") do
          Chef::Log.info("Removing profiles from #{new_resource}")
          load_balancer.client['LocalLB.VirtualServer'].remove_profile([new_resource.vs_name], [extra_profiles])
          current_resource.profiles(matching_profiles)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Delete the virtual server
      #
      def delete_virtual_server
        converge_by("Deleting #{new_resource}") do
          Chef::Log.info("Deleting #{new_resource}")
          load_balancer.client['LocalLB.VirtualServer'].delete_virtual_server([new_resource.vs_name])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Return message to display given new_resource enabled attribtue
      #
      # @return [String]
      #   message
      #
      def enabled_state_message
        if new_resource.enabled
          'Enabling'
        else
          'Disabling'
        end
      end

      #
      # Return F5 state value given new_resource enabled attribute
      #
      # @return [String]
      #   F5 string value for enabling/disabling a virtual server based on new_resource enabled parameter
      #
      def enabled_state
        if new_resource.enabled
          'STATE_ENABLED'
        else
          'STATE_DISABLED'
        end
      end

      #
      # Update current_resource with value from new_resource for given items
      #
      # @param [Array] items
      #   current_resource parameters to update with related new_resource parameters
      #
      def update_current_resource(items)
        items.each do |item|
          current_resource.send(item, new_resource.send(item))
        end
      end

      #
      # Return data structure for virtual server defenition given new_resource parameters
      #
      # @return [Array<Hash>]
      #   data structure for Virtual Server Defenition based on new_resource
      #
      def new_virtual_server_defenition
        [{
          'name' => new_resource.vs_name,
          'address' => new_resource.destination_address,
          'port' => new_resource.destination_port,
          'protocol' => new_resource.protocol
        }]
      end

      #
      # Return data structure for virtual server resource given new_resource parameters
      #
      # @return [Array<Hash>]
      #   data structure for Virtual Server Resource based on new_resource
      #
      def new_virtual_server_resource
        [{
          'type' => new_resource.type,
          'default_pool_name' => new_resource.default_pool
        }]
      end

      #
      # Update vlans assigned to virtual server
      #
      def update_vlans # rubocop:disable AbcSize
        converge_by("Updating #{new_resource} vlans") do
          Chef::Log.info "Updating #{new_resource} vlans"
          load_balancer.client['LocalLB.VirtualServer']
            .set_vlan([new_resource.vs_name],
                      [{ 'state' => new_resource.vlan_state,
                         'vlans' => new_resource.vlans }])
          current_resource.vlans(new_resource.vlans)
          current_resource.vlan_state(new_resource.vlan_state)

          new_resource.updated_by_last_action(true)
        end
      end

      def update_snat # rubocop:disable AbcSize
        converge_by("Updating #{new_resource} snat") do
          Chef::Log.info "Updating #{new_resource} snat"

          update_snat_none if new_resource.snat_type == 'SRC_TRANS_NONE'
          update_snat_automap if new_resource.snat_type == 'SRC_TRANS_AUTOMAP'
          update_snat_pool(new_resource.snat_pool) if new_resource.snat_type == 'SRC_TRANS_SNATPOOL'

          current_resource.snat_type(new_resource.snat_type)
          current_resource.snat_pool(new_resource.snat_pool)
        end
      end

      def update_snat_none
        load_balancer.client['LocalLB.VirtualServer']
          .set_snat_none([new_resource.vs_name])

        new_resource.updated_by_last_action(true)
      end

      def update_snat_automap
        load_balancer.client['LocalLB.VirtualServer']
          .set_snat_automap([new_resource.vs_name])

        new_resource.updated_by_last_action(true)
      end

      def update_snat_pool(pool)
        load_balancer.client['LocalLB.VirtualServer']
          .set_snat_pool([new_resource.vs_name], [pool])

        new_resource.updated_by_last_action(true)
      end

      #
      # Return data structure for default persistence profile server resource given
      #   new_resource parameters
      #
      # @return [Hash]
      #   data structure for default persistence profile based on new_resource
      #
      def default_persistence_profile_hash
        [{
          'profile_name' => new_resource.default_persistence_profile,
          'default_profile' => 'true'
        }]
      end

      #
      # Update the default persistence profile for the virtual server
      #
      def update_default_persistence_profile
        converge_by("Updating #{new_resource} default persistence profile") do
          Chef::Log.info("Updating #{new_resource} default persistence profile")
          update_fallback_persistence_profile('')
          remove_all_persistence_profiles
          add_persistence_profile unless new_resource.default_persistence_profile.empty?
        end
      end

      #
      # Remove all of the virtual server default persistence profiles
      #
      def remove_all_persistence_profiles
        load_balancer.client['LocalLB.VirtualServer']
          .remove_all_persistence_profiles [new_resource.vs_name]
        current_resource.default_persistence_profile('')

        new_resource.updated_by_last_action(true)
      end

      #
      # Add the virtual server default persistence profile
      #
      def add_persistence_profile
        load_balancer.client['LocalLB.VirtualServer']
          .add_persistence_profile [new_resource.vs_name],
                                   [default_persistence_profile_hash]
        current_resource.default_persistence_profile(new_resource.default_persistence_profile)

        new_resource.updated_by_last_action(true)
      end

      #
      # Set the virtual server fallback persistence profile
      #
      def update_fallback_persistence_profile(profile_name)
        converge_by("Updating #{new_resource} fallback persistence profile") do
          Chef::Log.info("Updating #{new_resource} fallback persistence profile")
          load_balancer.client['LocalLB.VirtualServer']
            .set_fallback_persistence_profile [new_resource.vs_name],
                                              [profile_name]
          current_resource.fallback_persistence_profile(profile_name)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Return data structure for rules for virtual server resource given
      #   new_resource parameters
      #
      # @return [Array<Hash>]
      #   data structure for rules based on new_resource
      #
      def rules_datastructure
        cnt = 0
        new_resource.rules.map do |rule|
          cnt += 1
          { 'rule_name' => rule, 'priority' => cnt }
        end
      end

      #
      # Remove all of the virtual server rules
      #
      def remove_all_rules
        converge_by("Removing all rules on #{new_resource}") do
          Chef::Log.info("Removing all rules on #{new_resource}")
          load_balancer.client['LocalLB.VirtualServer']
            .remove_all_rules [new_resource.vs_name]
          current_resource.rules([])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Add the virtual server rules
      #
      def add_rules # rubocop:disable AbcSize
        converge_by("Adding rules to #{new_resource}") do
          Chef::Log.info("Adding rules to #{new_resource}")
          load_balancer.client['LocalLB.VirtualServer']
            .add_rule [new_resource.vs_name],
                      [rules_datastructure]
          current_resource.rules(new_resource.rules)

          new_resource.updated_by_last_action(true)
        end
      end
    end
  end
end

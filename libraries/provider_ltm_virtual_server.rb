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

      def load_current_resource # rubocop:disable MethodLength
        @current_resource = Chef::Resource::F5LtmVirtualServer.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.vs_name(@new_resource.vs_name)
        @current_resource.default_persistence_profile_cnt = 0

        # Check if virtual server exists
        load_balancer.change_folder(@new_resource.vs_name)
        vs = load_balancer.ltm.virtual_servers.find { |v| v.name =~ /(^|\/)#{@new_resource.vs_name}$/ or v.name == @new_resource.vs_name }

        @current_resource.exists = !vs.nil?
        return @current_resource unless @current_resource.exists

        @current_resource.default_persistence_profile_cnt = vs.default_persistence_profile.size

        @current_resource.destination_address(vs.destination_address.gsub('/Common/', ''))
        @current_resource.destination_port(vs.destination_port)
        @current_resource.destination_wildmask(vs.destination_wildmask)
        @current_resource.source_address(vs.source_address)
        @current_resource.type(vs.type)
        @current_resource.default_pool(vs.default_pool.gsub('/Common/', ''))
        @current_resource.description(vs.description)
        @current_resource.rules(vs.rules)
        @current_resource.vlan_state(vs.vlans['state'])

        @current_resource.translate_address(vs.translate_address)
        @current_resource.translate_port(vs.translate_port)

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

        @current_resource
      end

      #
      # Create action for f5_icontrol_virtual_server provider
      #
      def action_create # rubocop:disable CyclomaticComplexity
        create_virtual_server unless current_resource.exists

        set_default_pool unless current_resource.default_pool == new_resource.default_pool

        set_description unless current_resource.description == new_resource.description

        set_destination_wildmask unless current_resource.destination_wildmask == new_resource.destination_wildmask
        set_source_address unless current_resource.source_address == new_resource.source_address

        if current_resource.destination_address.start_with?('/')
          cur_addr = current_resource.destination_address.split('/')[2]
        else
          cur_addr = current_resource.destination_address
        end
        if new_resource.destination_address.start_with?('/')
          new_addr = new_resource.destination_address.split('/')[2]
        else
          new_addr = new_resource.destination_address
        end

        #set_destination_address_port unless current_resource.destination_address == new_resource.destination_address
        set_destination_address_port unless cur_addr == new_addr
        set_destination_address_port unless current_resource.destination_port == new_resource.destination_port

        remove_all_rules unless match?('rules')
        remove_profiles unless match?('profiles')

        set_enabled_state unless current_resource.enabled == new_resource.enabled

        set_translate_address unless current_resource.translate_address == new_resource.translate_address
        set_translate_port unless current_resource.translate_port == new_resource.translate_port

        update_vlans unless current_resource.vlans == new_resource.vlans
        update_vlans unless current_resource.vlan_state == new_resource.vlan_state

        update_snat unless current_resource.snat_type == new_resource.snat_type
        update_snat unless current_resource.snat_pool == new_resource.snat_pool

        update_default_persistence_profile if current_resource.default_persistence_profile_cnt > 1
        update_default_persistence_profile unless current_resource.default_persistence_profile == new_resource.default_persistence_profile
        update_fallback_persistence_profile(new_resource.fallback_persistence_profile) unless current_resource.fallback_persistence_profile == new_resource.fallback_persistence_profile

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
        current_resource.send(attr) == new_resource.send(attr)
      end

      #
      # Create a new virtual server given new_resource attributes
      #
      def create_virtual_server
        converge_by("Create #{new_resource}") do
          Chef::Log.info("Create #{new_resource}")
          load_balancer.client['LocalLB.VirtualServer']
                       .create new_virtual_server_defenition, [new_resource.destination_wildmask],
                               new_virtual_server_resource, [new_resource.profiles]
          update_current_resource(%w(destination_address destination_port protocol
                                     destination_wildmask type default_pool profiles description
                                     translate_port translate_address source_address))
          current_resource.default_persistence_profile_cnt = 0
          current_resource.enabled(true)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set translate address state
      #
      def set_translate_address
        converge_by("Updating #{new_resource} translate address to #{new_resource.translate_address}") do
          Chef::Log.info("Updating #{new_resource} translate address to #{new_resource.translate_address}")
    
          st = new_resource.translate_address ? 'STATE_ENABLED' : 'STATE_DISABLED'
          load_balancer.client['LocalLB.VirtualServer'].set_translate_address_state([new_resource.vs_name], [st])
          current_resource.translate_address(new_resource.translate_address)

          new_resource.updated_by_last_action(true)
        end
      end


      #
      # Set translate port state
      #
      def set_translate_port
        converge_by("Updating #{new_resource} translate port to #{new_resource.translate_port}") do
          Chef::Log.info("Updating #{new_resource} translate port to #{new_resource.translate_port}")
    
          st = new_resource.translate_port ? 'STATE_ENABLED' : 'STATE_DISABLED'
          load_balancer.client['LocalLB.VirtualServer'].set_translate_port_state([new_resource.vs_name], [st])
          current_resource.translate_port(new_resource.translate_port)

          new_resource.updated_by_last_action(true)
        end
      end


      #
      # Set virtual server description based on new_resource default_pool parameter
      #
      def set_description
        converge_by("Updating #{new_resource} description to #{new_resource.description}") do
          Chef::Log.info("Updating #{new_resource} description to #{new_resource.description}")
          load_balancer.client['LocalLB.VirtualServer'].set_description([new_resource.vs_name], [new_resource.description])
          current_resource.description(new_resource.description)

          new_resource.updated_by_last_action(true)
        end
      end


      #
      # Set virtual server default pool based on new_resource default_pool parameter
      #
      def set_default_pool
        converge_by("Updating #{new_resource} default pool to #{new_resource.default_pool}") do
          Chef::Log.info("Updating #{new_resource} default pool to #{new_resource.default_pool}")
          load_balancer.client['LocalLB.VirtualServer'].set_default_pool_name([new_resource.vs_name], [new_resource.default_pool])
          current_resource.default_pool(new_resource.default_pool)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set virtual server source address
      #
      def set_source_address
        converge_by("Updating #{new_resource} source address to #{new_resource.source_address}") do
          Chef::Log.info("Updating #{new_resource} source address to #{new_resource.source_address}")
          load_balancer.client['LocalLB.VirtualServer'].set_source_address([new_resource.vs_name], [new_resource.source_address])
          current_resource.source_address(new_resource.source_address)

          new_resource.updated_by_last_action(true)
        end
      end


      #
      # Set virtual server wildmask based on new_resource wildmask parameter
      #
      def set_destination_wildmask
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
      def set_destination_address_port
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
      def add_profiles
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
      def remove_profiles
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
      def update_vlans
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

      def update_snat
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
      def add_rules
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

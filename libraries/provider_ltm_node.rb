#
# Author:: Jacob McCann (<jacob.mccann2@target.com>)
# Cookbook Name:: f5-bigip
# Provider:: ltm_node
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
    # Chef Provider for F5 LTM Node
    #
    class F5LtmNode < Chef::Provider
      include F5::Loader

      # Support whyrun
      def whyrun_supported?
        false
      end

      def load_current_resource # rubocop:disable AbcSize
        @current_resource = Chef::Resource::F5LtmNode.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.node_name(@new_resource.node_name)

        # If node exists load it's current state
        node = find_match_with_delete
        @current_resource.enabled(node['enabled']) unless node.nil?
        @current_resource.description(node['description']) unless node.nil?

        # preserve status
        if @new_resource.preserve_status
          @new_resource.enabled(node['enabled']) unless node.nil?
        end
        @current_resource
      end

      def action_create # rubocop:disable AbcSize
        # If node doesn't exist
        create_node unless current_resource.exists

        # If enable state isn't what we want
        set_enabled unless current_resource.enabled == new_resource.enabled
        set_description unless current_resource.description == new_resource.description
      end

      def action_delete
        delete_node if current_resource.exists
      end

      private

      #
      # Check if a node already exists, deleting any existing partially matching node
      #
      def find_match_with_delete # rubocop:disable AbcSize, MethodLength, CyclomaticComplexity, PerceivedComplexity
        load_balancer.change_folder(@new_resource.node_name)
        node = load_balancer.ltm.nodes.find { |n| n['name'] =~ %r{(^|\/)#{@new_resource.node_name}$} || n['name'] == @new_resource.node_name }
        addr_node = load_balancer.ltm.nodes.find { |n| n['address'] =~ %r{(^|\/)#{@new_resource.address}$} || n['name'] == @new_resource.address }
        @current_resource.exists = false
        if !node.nil?
          if !addr_node.nil?
            if node['address'] == addr_node['address']
              @current_resource.exists = true
            else
              delete_node(node['name'])
              delete_node(addr_node['name'])
            end
          else
            delete_node(node['name'])
          end
        elsif !addr_node.nil?
          delete_node(addr_node['name'])
        end

        node if @current_resource.exists
      end

      #
      # Create a new node from new_resource attributes
      #
      def create_node # rubocop:disable AbcSize
        converge_by("Create #{new_resource}") do
          Chef::Log.info "Create #{new_resource}"
          load_balancer.client['LocalLB.NodeAddressV2'].create([new_resource.node_name], [new_resource.address], [0])
          current_resource.enabled(true)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set node as description
      #
      def set_description # rubocop:disable AbcSize
        converge_by("#{enabled_msg} #{new_resource}") do
          Chef::Log.info "#{enabled_msg} #{new_resource}"
          load_balancer.client['LocalLB.NodeAddressV2'].set_description([new_resource.node_name], [new_resource.description])
          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set node as enabled or disabled given new_resource enabled attribute
      #
      def set_enabled # rubocop:disable AbcSize
        converge_by("#{enabled_msg} #{new_resource}") do
          Chef::Log.info "#{enabled_msg} #{new_resource}"
          load_balancer.client['LocalLB.NodeAddressV2'].set_session_enabled_state([new_resource.node_name], [enabled_state])
          current_resource.enabled(new_resource.enabled)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Return message to display given new_resource enabled attribtue
      #
      # @return [String]
      #   message
      #
      def enabled_msg
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
      #   F5 string value for enabling/disabling a node based on new_resource enabled parameter
      #
      def enabled_state
        if new_resource.enabled
          'STATE_ENABLED'
        else
          'STATE_DISABLED'
        end
      end

      #
      # Delete node
      #
      def delete_node(address = new_resource.node_name) # rubocop:disable AbcSize, MethodLength
        converge_by("Delete #{address}") do
          load_balancer.ltm.pools.all.each do |pool|
            member = pool.members.find { |m| m.address == address }
            next if member.nil?
            members = []
            members.push member
            Chef::Log.info "Delete #{address} from #{pool.name}"
            load_balancer.client['LocalLB.Pool'].remove_member_v2([pool.name], [members])
          end
          Chef::Log.info "Delete #{address}"
          load_balancer.client['LocalLB.NodeAddressV2'].delete_node_address([address])

          new_resource.updated_by_last_action(true)
        end
      end
    end
  end
end

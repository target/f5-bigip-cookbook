#
# Author:: Jacob McCann (<jacob.mccann2@target.com>)
# Cookbook Name:: f5-bigip
# Provider:: ltm_pool
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
    # Chef Provider for F5 LTM Pool
    #
    class F5LtmPool < Chef::Provider
      include F5::Loader

      # Support whyrun
      def whyrun_supported?
        false
      end

      def load_current_resource # rubocop:disable MethodLength, AbcSize
        @current_resource = Chef::Resource::F5LtmPool.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.pool_name(@new_resource.pool_name)

        load_balancer.change_folder(@new_resource.pool_name)
        pool = load_balancer.ltm.pools.find { |p| p.name =~ %r{(^|\/)#{@new_resource.pool_name}$} || p.name == @new_resource.pool_name }

        @current_resource.exists = !pool.nil?

        # If pool exists load it's current state
        if @current_resource.exists
          @current_resource.lb_method(pool.lb_method)
          @current_resource.description(pool.description)
          @current_resource.monitors(pool.monitors['monitor_templates'])
          @current_resource.monitor_type = pool.monitors['type']
          @current_resource.members(pool.members)
        end
        @current_resource
      end

      def action_create # rubocop:disable AbcSize, CyclomaticComplexity
        create_pool unless current_resource.exists
        set_lb_method unless current_resource.lb_method == new_resource.lb_method
        set_description unless current_resource.description == new_resource.description
        set_members unless missing_members.empty? && extra_members.empty?
        set_health_monitors unless current_health_monitors == new_health_monitors
      end

      def action_delete
        delete_pool if current_resource.exists
      end

      private

      #
      # Create a new pool given new_resource attributes
      #
      def create_pool # rubocop:disable MethodLength, AbcSize
        converge_by("Create #{new_resource} pool") do
          Chef::Log.info "Create #{new_resource} pool"
          members = new_resource.members.map do |member|
            { 'address' => member['address'], 'port' => member['port'] }
          end

          load_balancer.change_folder(new_resource.pool_name)
          load_balancer.client['LocalLB.Pool'].create_v2([new_resource.pool_name], [new_resource.lb_method], [members])

          current_resource.lb_method(new_resource.lb_method)
          current_resource.description(new_resource.description)
          current_resource.members(new_resource.members)
          current_resource.monitors([])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set load balancing method given new_resource lb_method attribute
      #
      def set_lb_method # rubocop:disable AbcSize
        converge_by("Update #{new_resource} pool lb method") do
          Chef::Log.info "Update #{new_resource} pool lb method"
          load_balancer.client['LocalLB.Pool'].set_lb_method([new_resource.pool_name], [new_resource.lb_method])
          current_resource.lb_method(new_resource.lb_method)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set descrition
      #
      def set_description # rubocop:disable AbcSize
        converge_by("Update #{new_resource} pool description") do
          Chef::Log.info "Update #{new_resource} pool description"
          load_balancer.client['LocalLB.Pool'].set_description([new_resource.pool_name], [new_resource.description])
          current_resource.description(new_resource.description)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set pool members for pool given new_resource members parameter
      #
      def set_members # rubocop:disable AbcSize, MethodLength
        converge_by("Update #{new_resource} with additional members") do
          Chef::Log.info "Update #{new_resource} with additional members"
          members = []
          missing_members.each do |member|
            members << { 'address' => member['address'],
                         'port' => member['port'] }
          end

          load_balancer.client['LocalLB.Pool'].add_member_v2([new_resource.pool_name], [missing_members])
          load_balancer.client['LocalLB.Pool'].remove_member_v2([new_resource.pool_name], [extra_members])

          current_resource.members(@new_resource.members)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set pool health monitors given new_resource monitors parameter
      #
      def set_health_monitors # rubocop:disable AbcSize, MethodLength
        converge_by("Update #{new_resource} monitors") do
          Chef::Log.info "Update #{new_resource} monitors"
          load_balancer.client['LocalLB.Pool'].set_monitor_association(
            [
              'pool_name' => new_resource.pool_name,
              'monitor_rule' => {
                'type' => monitor_rule_type, 'quorum' => 0,
                'monitor_templates' => new_resource.monitors
              }
            ]
          )
          current_resource.monitors(new_resource.monitors)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Delete the pool
      #
      def delete_pool
        converge_by("Delete #{current_resource} pool") do
          Chef::Log.info "Delete #{current_resource} pool"
          load_balancer.client['LocalLB.Pool'].delete_pool([current_resource.pool_name])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Return F5 monitor rule type given number of monitors provided in
      # new resource monitors parameter
      #
      # @return [String]
      #   F5 rule type
      #
      def monitor_rule_type
        case new_resource.monitors.size
        when 0
          'MONITOR_RULE_TYPE_NONE'
        when 1
          'MONITOR_RULE_TYPE_SINGLE'
        else
          'MONITOR_RULE_TYPE_AND_LIST'
        end
      end

      #
      # Return current health monitors associated with pool
      #
      # @return [Array]
      #   monitors currently associated with pool
      #
      def current_health_monitors
        # Strip folder (good/bad?)
        current_resource.monitors.map { |m| m.gsub(%r{\/.*\/}, '') }.uniq.sort
      end

      #
      # Return defined health monitors for the pool
      #
      # @return [Array]
      #   monitors defined for pool to have
      #
      def new_health_monitors
        new_resource.monitors.map { |m| m.gsub(%r{\/.*\/}, '') }.uniq.sort
      end

      #
      # Return pool members currently associated with the pool
      #
      # @return [Array]
      #   pool members currently associated with the pool
      #
      def current_members
        members = current_resource.members.map { |m| slice(m.to_hash, 'address', 'port') }

        # Strip off folder (good/bad?)
        # Set port to String from Integer
        members.each do |member|
          member['address'] = member['address'].gsub(%r{\/.*\/}, '')
          member['port'] = member['port'].to_s
        end
        members
      end

      #
      # Return pool members that are defined for the pool
      #
      # @return [Array]
      #   pool members defined for the pool to have
      #
      def new_members
        members = new_resource.members.map { |m| slice(m.to_hash, 'address', 'port') }

        # Strip off folder (good/bad?)
        members.each do |member|
          member['address'] = member['address'].gsub(%r{\/.*\/}, '')
          member['port'] = member['port'].to_s
        end
        members
      end

      #
      # Return pool members defined that are not currently associated to pool
      #
      # @return [Array]
      #   defined pool members not currently associated with pool
      #
      def missing_members
        Chef::Log.info(current_members)
        Chef::Log.info(new_members)
        Chef::Log.info(new_members - (current_members & new_members))

        new_members - (current_members & new_members)
      end

      #
      # Return pool members that should be removed from the pool
      #
      # @return [Array]
      #   pool members to remove from the pool
      #
      def extra_members
        Chef::Log.info(current_members)
        Chef::Log.info(new_members)
        Chef::Log.info(current_members - (current_members & new_members))

        current_members - (current_members & new_members)
      end

      #
      # Return new hash with subset of keys
      #
      # @param [Hash] s
      #   Hash to get values from
      # @param [Array] keys
      #   Keys to retrieve from Hash
      #
      # @return [Hash]
      #   new Hash that contains only the subset of keys
      #
      def slice(s, *keys)
        h = {}
        keys.each { |k| h[k] = s[k] }
        h
      end
    end
  end
end

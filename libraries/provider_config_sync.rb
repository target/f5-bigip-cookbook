#
# Author:: Jacob McCann (<jacob.mccann2@target.com>)
# Cookbook Name:: f5-bigip
# Provider:: config_sync
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
    # Chef Provider for F5 Config Sync
    #
    class F5ConfigSync < Chef::Provider
      include F5::Loader

      def load_current_resource
        @current_resource ||= Chef::Resource::F5ConfigSync.new(new_resource.name)
        @current_resource.f5(new_resource.f5)
        @current_resource
      end

      # Support whyrun
      def whyrun_supported?
        false
      end

      def action_run
        synchronize_to_all_groups if load_balancer.active?
      end

      private

      #
      # Push config to peers
      #
      def synchronize_to_all_groups # rubocop:disable AbcSize
        Chef::Log.info "No peers for #{load_balancer.system_hostname}" if load_balancer.device_groups.empty?
        return if load_balancer.device_groups.empty?

        converge_by("Pushing configs from #{new_resource.f5} to peers") do
          Chef::Log.info "Pushing configs from #{new_resource.f5} to peers"

          load_balancer.device_groups.each do |grp|
            Chef::Log.info "  Pushing config from #{load_balancer.system_hostname} to group #{grp}"
            load_balancer.client['System.ConfigSync'].synchronize_to_group_v2(grp, load_balancer.system_hostname, true)
            new_resource.updated_by_last_action(true)
          end
        end
      end
    end
  end
end

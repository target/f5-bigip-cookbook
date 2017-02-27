#
# Author:: Sergio Rua <sergio@rua.me.uk>
# Cookbook Name:: f5-bigip
# Provider:: ltm_string_class
#
# Copyright:: 2015 Sky Betting and Gaming
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
    # Chef Provider for F5 LTM String Class
    #
    class F5LtmStringClass < Chef::Provider
      include F5::Loader

      # Support whyrun
      def whyrun_supported?
        false
      end

      def load_current_resource # rubocop:disable AbcSize, MethodLength
        @current_resource = Chef::Resource::F5LtmStringClass.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.sc_name(@new_resource.sc_name)
        @current_resource.records(@new_resource.records)

        Chef::Log.info("Changing partition to #{@new_resource.sc_name}")
        load_balancer.change_folder(@new_resource.sc_name)
        if @new_resource.sc_name.include?('/')
          @current_resource.sc_name(@new_resource.sc_name.split('/')[2])
        end
        sc = load_balancer.client['LocalLB.Class'].get_string_class([@new_resource.sc_name]).find { |n| n['name'] == @new_resource.sc_name }
        @current_resource.exists = !sc['members'].empty?

        return @current_resource unless @current_resource.exists

        string_class = [{ 'name' => sc['name'], 'members' => sc['members'] }]
        string_class_values = load_balancer.client['LocalLB.Class'].get_string_class_member_data_value(string_class)

        @current_resource.update = sc['members'].sort != @new_resource.records.keys.sort || string_class_values[0].sort != @new_resource.records.values.sort

        recs = {}
        string_class[0]['members'].each_with_index do |m, i|
          recs[m] = string_class_values[i]
        end
        @current_resource.records(recs)

        @current_resource
      end

      def action_create
        create_sc unless current_resource.exists && !current_resource.update
      end

      def action_delete
        delete_sc if current_resource.exists
      end

      private

      #
      # Create a new node from new_resource attribtues
      #
      def create_sc # rubocop:disable AbcSize, MethodLength
        converge_by("Create/Update data list #{new_resource}") do
          Chef::Log.info "Create #{new_resource}"
          new_sc = { 'name' => new_resource.sc_name, 'members' => new_resource.records.keys }
          new_values = new_resource.records.values

          if current_resource.update
            load_balancer.client['LocalLB.Class'].modify_string_class([new_sc])
          else
            load_balancer.client['LocalLB.Class'].create_string_class([new_sc])
          end
          load_balancer.client['LocalLB.Class'].set_string_class_member_data_value([new_sc], [new_values])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Delete node
      #
      def delete_sc
        converge_by("Delete #{new_resource}") do
          Chef::Log.info "Delete #{new_resource}"
          load_balancer.client['LocalLB.Class'].delete_class([new_resource.sc_name])

          new_resource.updated_by_last_action(true)
        end
      end
    end
  end
end

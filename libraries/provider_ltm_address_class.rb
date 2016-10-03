#
# Author:: Sergio Rua <sergio@rua.me.uk>
# Cookbook Name:: f5-bigip
# Provider:: ltm_node
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
    # Chef Provider for F5 LTM Node
    #
    class F5LtmAddressClass < Chef::Provider
      include F5::Loader

      # Support whyrun
      def whyrun_supported?
        false
      end

      def load_current_resource
        @current_resource = Chef::Resource::F5LtmAddressClass.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.sc_name(@new_resource.sc_name)
        @current_resource.records(@new_resource.records)

        Chef::Log.info("Changing partition to #{@new_resource.sc_name}")
        load_balancer.change_folder(@new_resource.sc_name)
        if @new_resource.sc_name.include?("/")
          @current_resource.sc_name (@new_resource.sc_name.split("/")[2])
        end
        sc = load_balancer.client['LocalLB.Class'].get_address_class([@new_resource.sc_name]).find { |n| n['name'] == @new_resource.sc_name }
        @current_resource.exists = !sc['members'].empty?

        return @current_resource unless @current_resource.exists

        address_class = [{"name" => sc['name'], "members" => sc['members']}]
        address_class_values = load_balancer.client['LocalLB.Class'].get_address_class_member_data_value(address_class)
        
        require 'pp'
        pp sc['members']
#        if sc['members'] != @new_resource.records.keys.sort or address_class_values[0].sort != @new_resource.records.values.sort
#          @current_resource.update = true
#        else
#          @current_resource.update = false
#        end

        recs={}
        address_class[0]['members'].each_with_index do |m,i|
          recs[m] = address_class_values[i]
        end
        @current_resource.records(recs)

        @current_resource
      end

      def action_create
        # If node doesn't exist
        if not current_resource.exists or current_resource.update
          create_address_class
        end
      end

      def action_delete
        delete_sc if current_resource.exists
      end

      private

      #
      # Create a new node from new_resource attribtues
      #
      def create_address_class
        converge_by("Create/Update data list #{new_resource}") do
          Chef::Log.info "Create #{new_resource}"
          new_sc = {"name" => new_resource.sc_name, "members" => new_resource.records}
          new_values = new_resource.records.values

          if current_resource.update
            load_balancer.client['LocalLB.Class'].modify_address_class([new_sc])
          else
            load_balancer.client['LocalLB.Class'].create_address_class([new_sc])
          end
          load_balancer.client['LocalLB.Class'].set_address_class_member_data_value([new_sc], [new_values])

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

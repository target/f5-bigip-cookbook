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

require 'erb'
require 'ostruct'

class Chef
  class Provider
    #
    # Chef Provider for F5 LTM Node
    #
    class F5LtmIrule < Chef::Provider
      include F5::Loader

      # Support whyrun
      def whyrun_supported?
        false
      end

      def load_current_resource
        @current_resource = Chef::Resource::F5LtmIrule.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.template(@new_resource.template)
        @current_resource.irule_name(@new_resource.irule_name)

        if @new_resource.content.nil? and @new_resource.template.nil?
          fail "Resource #{@new_resource.name} requires either 'content' or 'template'"
        end

        load_balancer.change_folder(@new_resource.irule_name)

        if not @new_resource.template.nil?
          @new_resource.content(load_template)
        else
          @new_resource.content(@new_resource.content)
        end

        if @new_resource.irule_name.include?('/')
          rule_name = @new_resource.irule_name
        else
          rule_name = "/#{load_balancer.active_folder}/#{@new_resource.irule_name}"
        end

        # Important: .query_rule will not find the rule if the content of the rule is empty
        #            Pretty bizare behaviour in the API we'll have to work with
        if load_balancer.client['LocalLB.Rule'].get_list.include?(rule_name)
          @current_resource.exists = true
          current_rule = load_balancer.client['LocalLB.Rule'].query_rule([rule_name])[0]
          if not current_rule.nil?
            @current_resource.content(current_rule['rule_definition'])
          else
            current_rule = { 'rule_name' => rule_name, 'rule_definition' => '' }
          end
        end

        return @current_resource unless @current_resource.exists

        @current_resource.update = true if current_rule['rule_definition'] != @new_resource.content

        @current_resource
      end

      def action_create
        if current_resource.update
          update_irule
        elsif not current_resource.exists
          create_irule
        end
      end

      def action_delete
        delete_irule if current_resource.exists
      end

      private

      def load_template
        def erb(template_file, vars)
          template = ::File.read(template_file)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end

        cb = run_context.cookbook_collection[cookbook_name]
        template = cb.template_filenames.find { |t| ::File.basename(t) == @new_resource.template }
        if not template or not ::File.exists?(template)
          fail "Template #{@new_resource.template} not found"
        end

        Chef::Log.info("Generating iRule from template #{template}")
        erb(template, @new_resource.variables)
      end

      #
      # Update iRule with new content
      #
      def update_irule
        converge_by("Update iRule #{new_resource}") do
          Chef::Log.info "Update #{new_resource}"
          new_irule = {"rule_name" => new_resource.irule_name, "rule_definition" => new_resource.content}

          load_balancer.client['LocalLB.Rule'].modify_rule([new_irule])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Create a new iRule
      #
      def create_irule
        converge_by("Create iRule #{new_resource}") do
          Chef::Log.info "Create #{new_resource}"
          new_irule = {"rule_name" => new_resource.irule_name, "rule_definition" => new_resource.content}

          load_balancer.client['LocalLB.Rule'].create([new_irule])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Delete node
      #
      def delete_irule
        converge_by("Delete #{new_resource}") do
          Chef::Log.info "Delete #{new_resource}"
          load_balancer.client['LocalLB.Rule'].delete_rule([new_resource.irule_name])

          new_resource.updated_by_last_action(true)
        end
      end
    end
  end
end

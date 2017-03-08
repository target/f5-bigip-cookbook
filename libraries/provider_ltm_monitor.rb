#
# Author:: Jacob McCann (<jacob.mccann2@target.com>)
# Cookbook Name:: f5-bigip
# Provider:: ltm_monitor
#
# Copyright:: 2014, Target Corporation
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
    # Chef Provider for F5 LTM Monitor
    #
    class F5LtmMonitor < Chef::Provider
      include F5::Loader

      # Support whyrun
      def whyrun_supported?
        false
      end

      def load_current_resource # rubocop:disable AbcSize
        @current_resource = Chef::Resource::F5LtmMonitor.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.monitor_name(@new_resource.monitor_name)

        load_balancer.change_folder(@new_resource.monitor_name)
        monitor = load_balancer.ltm.monitors.find { |m| m.name =~ %r{(^|\/)#{@new_resource.monitor_name}$} || m.name == @new_resource.monitor_name }
        @current_resource.exists = !monitor.nil?
        return @current_resource unless @current_resource.exists

        populate_current_resource(monitor)
        fix_parent_template_value

        @current_resource
      end

      def action_create # rubocop:disable AbcSize, CyclomaticComplexity, PerceivedComplexity
        create_template unless current_resource.exists

        set_template_destination if current_resource.dest_addr_type != new_resource.dest_addr_type
        set_template_destination if current_resource.dest_addr_ip != new_resource.dest_addr_ip
        set_template_destination if current_resource.dest_addr_port != new_resource.dest_addr_port

        set_template_interval if current_resource.interval != new_resource.interval
        set_template_description if current_resource.description != new_resource.description
        set_template_timeout if current_resource.timeout != new_resource.timeout

        set_template_parent if current_resource.parent != new_resource.parent

        set_user_values if new_resource.user_values != {} && current_resource.user_values != new_resource.user_values
      end

      def action_delete
        delete_template if current_resource.exists
      end

      private

      #
      # Populate current_resource with values gathered via F5 API
      #
      # @param [F5::Monitor] monitor
      #   f5 monitor object with data loaded from f5 API
      #
      def populate_current_resource(monitor)
        %w(parent description interval timeout dest_addr_type dest_addr_ip dest_addr_port user_values type).each do |item|
          current_resource.send(item, monitor.send(item))
        end
      end

      #
      # Create a new monitor from new_resource attribtues
      #
      def create_template # rubocop:disable AbcSize
        converge_by("Create #{new_resource}") do
          Chef::Log.info "Create #{new_resource}"
          load_balancer.client['LocalLB.Monitor'].create_template(monitor_template, common_attributes)

          # Reload monitor info from F5
          load_balancer.ltm.monitors.refresh_all

          # Reload state of current_resource
          load_current_resource

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set monitor destination address
      #
      def set_template_destination # rubocop:disable AbcSize
        converge_by("Update #{new_resource} destination") do
          Chef::Log.info "Update #{new_resource} destination"
          Chef::Log.info "Monitor destination for #{new_resource} will fail if monitor is currently associated"
          load_balancer.client['LocalLB.Monitor'].set_template_destination([new_resource.monitor_name], [monitor_ip_port])
          update_current_resource(%w(dest_addr_type dest_addr_ip dest_addr_port))

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set monitor description
      #
      def set_template_description # rubocop:disable AbcSize
        converge_by("Update #{new_resource} description") do
          Chef::Log.info "Update #{new_resource} description"
          current_resource.description(new_resource.description)
          load_balancer.client['LocalLB.Monitor'].set_description([new_resource.monitor_name], [new_resource.description])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set monitor interval
      #
      def set_template_interval
        converge_by("Update #{new_resource} interval") do
          Chef::Log.info "Update #{new_resource} interval"
          set_integer_for('ITYPE_INTERVAL', new_resource.interval)
          current_resource.interval(new_resource.interval)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set monitor timeout
      #
      def set_template_timeout
        converge_by("Update #{new_resource} timeout") do
          Chef::Log.info "Update #{new_resource} timeout"
          set_integer_for('ITYPE_TIMEOUT', new_resource.timeout)
          current_resource.timeout(new_resource.timeout)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set Send String
      #
      def set_template_send_string
        set_template_string(%w(TTYPE_HTTP TTYPE_HTTPS TTYPE_TCP),
                            'STYPE_SEND',
                            'Send String')
      end

      #
      # Set Receive String
      #
      def set_template_receive_string
        set_template_string(%w(TTYPE_HTTP TTYPE_HTTPS TTYPE_TCP),
                            'STYPE_RECEIVE',
                            'Receive String')
      end

      #
      # Set Username String
      #
      def set_template_username_string
        set_template_string(%w(TTYPE_HTTP TTYPE_HTTPS TTYPE_NNTP TTYPE_FTP TTYPE_POP3 TTYPE_SQL TTYPE_IMAP TTYPE_RADIUS TTYPE_RADIUS_ACCOUNTING TTYPE_LDAP TTYPE_WMI TTYPE_SIPTTYPE_TCP),
                            'STYPE_USERNAME',
                            'Username String')
      end

      #
      # Set Password String
      #
      def set_template_password_string
        set_template_string(%w(TTYPE_HTTP TTYPE_HTTPS TTYPE_NNTP TTYPE_FTP TTYPE_POP3 TTYPE_SQL TTYPE_IMAP TTYPE_RADIUS TTYPE_LDAP TTYPE_WMI TTYPE_SIPTTYPE_TCP),
                            'STYPE_PASSWORD',
                            'Password String')
      end

      def set_template_dns_query_name
        set_template_string(%w(TTYPE_DNS),
                            'STYPE_QUERY_NAME',
                            'Query name')
      end

      def set_template_dns_query_type
        set_template_string(%w(TTYPE_DNS),
                            'STYPE_QUERY_TYPE',
                            'Query type')
      end

      def set_template_dns_query_answer
        set_template_string(%w(TTYPE_DNS),
                            'STYPE_ANSWER_CONTAINS',
                            'Query answer')
      end

      #
      # Wrapper function for setting string values for an f5 type
      #
      def set_template_string(monitor_types, string_type, type_description)
        error_message = "Can not set '#{type_description}' for #{new_resource} as it's type is currently #{current_resource.type}"
        raise error_message unless monitor_types.include? current_resource.type

        converge_by("Update #{new_resource} '#{type_description}'") do
          set_string_for(string_type)

          new_resource.updated_by_last_action(true)
        end
      end

      #
      #
      #
      def set_user_values # rubocop:disable AbcSize, CyclomaticComplexity, PerceivedComplexity
        set_template_send_string unless user_values_match? 'STYPE_SEND'
        set_template_receive_string unless user_values_match? 'STYPE_RECEIVE'
        set_template_username_string unless user_values_match? 'STYPE_USERNAME'
        set_template_password_string unless user_values_match? 'STYPE_PASSWORD'
        set_template_dns_query_name unless user_values_match? 'STYPE_QUERY_NAME'
        set_template_dns_query_type unless user_values_match? 'STYPE_QUERY_TYPE'
        set_template_dns_query_answer unless user_values_match? 'STYPE_ANSWER_CONTAINS'
      end

      #
      #
      #
      def user_values_match?(type) # rubocop:disable AbcSize
        # 'Skip' by returning true if new_resource is not set with the type
        return true unless new_resource.user_values.key? type

        # No match if current_resource does not have it set
        raise "#{current_resource} missing string value for #{type}" unless current_resource.user_values.key? type

        return false if current_resource.user_values[type] != new_resource.user_values[type]
        true
      end

      #
      # Set monitor type
      #
      def set_template_type
        Chef::Log.info "#{new_resource} monitor type incorrect, attempting to delete and recreate"
        recreate_template
      end

      #
      # Set monitor parent
      #
      def set_template_parent
        Chef::Log.info "#{new_resource} monitor parent incorrect, attempting to delete and recreate"
        recreate_template
      end

      #
      # Recreate a monitor by deleting it and creating it
      #
      def recreate_template
        Chef::Log.info "Monitor recreation for #{new_resource} will fail if monitor is currently associated"
        delete_template
        create_template
      end

      #
      # Delete monitor
      #
      def delete_template
        converge_by("Delete #{new_resource}") do
          Chef::Log.info "Delete #{new_resource}"
          load_balancer.client['LocalLB.Monitor'].delete_template([new_resource.monitor_name])

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Set Monitor value for F5 'type'
      #
      # @param [String] type
      #   the F5 type to set the value for
      # @param [Integer] value
      #   the value to set
      #
      def set_integer_for(type, value)
        load_balancer.client['LocalLB.Monitor']
                     .set_template_integer_property([new_resource.monitor_name],
                                                    [{ 'type' => type, 'value' => value }])
      end

      #
      # Set Monitor String value for F5 'type'
      #
      # @param [String] type
      #   the F5 type to set the value for
      #
      def set_string_for(type) # rubocop:disable AccessorMethodName, AbcSize
        Chef::Log.info "Update #{new_resource} String '#{type}'"
        load_balancer.client['LocalLB.Monitor']
                     .set_template_string_property([new_resource.monitor_name],
                                                   [{ 'type' => type,
                                                      'value' => new_resource.user_values[type] }])
        current_resource.user_values(current_resource.user_values.merge(type => new_resource.user_values[type]))
      end

      #
      # Return F5 MonitorTemplate
      #
      # @return [Array<Hash>]
      #   f5 MonitorTemplate data structure
      #
      def monitor_template
        [{ 'template_name' => new_resource.monitor_name, 'template_type' => nil }]
      end

      #
      # Return F5 CommonAttributes
      #
      # @return [Array<Hash>]
      #   f5 CommonAttributes data structure
      #
      def common_attributes
        [{
          'parent_template' => new_resource.parent,
          'interval' => new_resource.interval,
          'description' => new_resource.description,
          'timeout' => new_resource.timeout,
          'dest_ipport' => monitor_ip_port,
          'is_read_only' => 'false',
          'is_directly_usable' => 'true'
        }]
      end

      #
      # Return F5 MonitorIPPort
      #
      # @return [Array<Hash>]
      #   f5 MonitorIPPort data structure
      #
      def monitor_ip_port
        {
          'address_type' => new_resource.dest_addr_type,
          'ipport' => {
            'address' => new_resource.dest_addr_ip,
            'port' => new_resource.dest_addr_port
          }
        }
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
      # Remove /Common from current_resource parent value if new_resource has no folder.
      # This is because a folder is assumed to be /Common if not present when sent to 11.x
      # APIs.  Also, on 10.x there are no folders.
      #
      def fix_parent_template_value
        return if new_resource.parent =~ %r{^/[A-Za-z0-9]+/.*}
        current_resource.parent(current_resource.parent.gsub(%r{^/Common/}, ''))
      end
    end
  end
end

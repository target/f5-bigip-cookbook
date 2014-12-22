#
# Cookbook Name:: f5-bigip
# Library:: F5::LoadBalancer::Ltm::Monitors
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

require 'load_balancer/ltm/monitors/monitor'
require 'forwardable'

module F5
  class LoadBalancer
    class Ltm
      # A collection of monitors.  This Class is an interface for sending bulk
      # updates to F5 for multiple items in a single API call.
      class Monitors
        include ::Enumerable
        extend ::Forwardable

        attr_reader :monitors

        def_delegators :@monitors, :find

        def initialize(client)
          @client = client
          refresh_all
        end

        #
        # The names of all the monitors
        #
        def names
          @monitors.map { |m| m.name }
        end

        #
        # Refresh all monitor data
        #
        def refresh_all
          @monitors = @client['LocalLB.Monitor'].get_template_list
                                                .map { |m| F5::LoadBalancer::Ltm::Monitors::Monitor.new(m) }
          @monitors.reject! { |m| root_templates.include? m.name }
          refresh_parent
          refresh_destination
          refresh_interval
          refresh_timeout
          refresh_send_string
          refresh_receive_string
        end

        #
        # Update the parent template
        #
        def refresh_parent
          parents = @client['LocalLB.Monitor'].get_parent_template(names)
          @monitors.each_with_index { |monitor, idx| monitor.parent = parents[idx] }
        end

        #
        # Update the destination address information for the monitors
        #
        def refresh_destination
          dests = @client['LocalLB.Monitor'].get_template_destination(names)
          @monitors.each_with_index do |monitor, idx|
            monitor.dest_addr_type = dests[idx]['address_type']
            monitor.dest_addr_ip = dests[idx]['ipport']['address']
            monitor.dest_addr_port = dests[idx]['ipport']['port']
          end
        end

        #
        # Update the interval value for the monitors
        #
        def refresh_interval
          refresh_integer_for('interval', 'ITYPE_INTERVAL')
        end

        #
        # Update the timeout value for the monitors
        #
        def refresh_timeout
          refresh_integer_for('timeout', 'ITYPE_TIMEOUT')
        end

        #
        # Update the 'directly usable' value for the monitors
        #
        def refresh_directly_usable
          booleans = @client['LocalLB.Monitor'].is_template_directly_usable(names)
          @monitors.each_with_index { |monitor, idx| monitor.directly_usable = booleans[idx] }
        end

        #
        # Update send value for the monitors with type [TCP, HTTP, HTTPS]
        #
        def refresh_send_string
          monitors = monitors_are(%w(TTYPE_HTTP TTYPE_HTTPS TTYPE_TCP))
          refresh_string_for(monitors, 'STYPE_SEND')
        end

        #
        # Update receive string value for the monitors with type [TCP, HTTP, HTTPS]
        #
        def refresh_receive_string
          monitors = monitors_are(%w(TTYPE_HTTP TTYPE_HTTPS TTYPE_TCP))
          refresh_string_for(monitors, 'STYPE_RECEIVE')
        end

        private

        #
        # A list of root tempates
        #
        # @return [Array<String>]
        #   an array of root templates
        #
        def root_templates
          @root_templates ||= begin
            booleans = @client['LocalLB.Monitor'].is_template_root(names)
            names.each_with_index.map { |name, idx| name if booleans[idx] }.compact.uniq
          end
        end

        #
        # Update Monitor Integer attribute 'item' from F5 'type'
        #
        # @param [String] attribute
        #   the class attribute to update
        # @param [String] type
        #   the F5 type to get the value from
        #
        def refresh_integer_for(attribute, type)
          # Call method for each monitor/type combo individually as it doesn't seem to work correctly
          # when sending an array of monitors/types to get values for
          # Following is what SHOULD have worked instead ...
          # @client['LocalLB.Monitor'].get_template_integer_property(names, types)
          @monitors.each do |monitor|
            value = @client['LocalLB.Monitor'].get_template_integer_property([monitor.name], [type])
            monitor.send("#{attribute}=", value.first['value'])
          end
        end

        #
        # Update Monitor String attribute 'item' from F5 'type'
        #
        # @param [Array<F5::Monitor>] monitors
        #   the subset of monitors to update the value for
        # @param [String] type
        #   the F5 type to get the value from
        #
        def refresh_string_for(monitors, type)
          # Call method for each monitor/type combo individually as it doesn't seem to work correctly
          # when sending an array of monitors/types to get values for
          # Following is what SHOULD have worked instead ...
          # @client['LocalLB.Monitor'].get_template_integer_property(names, types)
          monitors.each do |monitor|
            value = @client['LocalLB.Monitor'].get_template_string_property([monitor.name], [type])
            monitor[type] = value.first['value']
          end
        end

        #
        # Return monitors matching the given type
        #
        # @param [Array<String>] types
        #   types of monitors to return
        #
        # @return [Array<F5::Monitor>]
        #   monitors that match the given types
        #
        def monitors_are(types)
          @monitors.select { |m| types.include? m.type }
        end
      end
    end
  end
end

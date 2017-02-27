#
# Author:: Jacob McCann (<jacob.mccann2@target.com>)
# Cookbook Name:: f5-bigip
# Resource:: ltm_monitor
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
  class Resource
    #
    # Chef Resource for F5 LTM Monitor
    #
    class F5LtmMonitor < Chef::Resource
      PORTS_REGEX ||= /^(6553[0-5]|655[0-2]\d|65[0-4]\d\d|6[0-4]\d{3}|[1-5]\d{4}|[1-9]\d{0,3}|0)$/
      IP_REGEX ||= /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
      ADDR_TYPE ||= %w(
        ATYPE_UNSET
        ATYPE_STAR_ADDRESS_STAR_PORT
        ATYPE_STAR_ADDRESS_EXPLICIT_PORT
        ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT
        ATYPE_STAR_ADDRESS
        ATYPE_EXPLICIT_ADDRESS
      ).freeze

      attr_accessor :exists

      def initialize(name, run_context = nil)
        super
        @resource_name = :f5_ltm_monitor
        @provider = Chef::Provider::F5LtmMonitor
        @action = :create
        @allowed_actions = [:create, :delete]

        # This is equivalent to setting :name_attribute => true
        @monitor_name = name

        # Now we need to set up any resource defaults
        set_defaults
      end

      def monitor_name(arg = nil)
        set_or_return(:monitor_name, arg, :kind_of => String, :required => true)
      end

      def f5(arg = nil)
        set_or_return(:f5, arg, :kind_of => String, :required => true)
      end

      def parent(arg = nil)
        set_or_return(:parent, arg, :kind_of => String)
      end

      def interval(arg = nil)
        set_or_return(:interval, arg, :kind_of => Integer)
      end

      def timeout(arg = nil)
        set_or_return(:timeout, arg, :kind_of => Integer)
      end

      def dest_addr_type(arg = nil)
        set_or_return(:dest_addr_type, arg, :kind_of => String, :equal_to => ADDR_TYPE)
      end

      def dest_addr_ip(arg = nil)
        set_or_return(:dest_addr_ip, arg, :kind_of => String)
      end

      def description(arg = nil)
        set_or_return(:description, arg, :kind_of => String)
      end

      def dest_addr_port(arg = nil)
        set_or_return(:dest_addr_port, arg, :kind_of => Integer, :regex => PORTS_REGEX)
      end

      def user_values(arg = nil)
        set_or_return(:user_values, arg, :kind_of => Hash)
      end

      # Track value of type but not as an attribute that is user controlled
      def type(arg = nil)
        return @type if arg.nil?
        @type = arg
      end

      private

      def set_defaults
        @parent = 'https'
        @interval = 5
        @timeout = 16
        @dest_addr_type = 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT'
        @dest_addr_ip = '0.0.0.0'
        @dest_addr_port = 443
        @description = ''
        @user_values = {}
      end
    end
  end
end

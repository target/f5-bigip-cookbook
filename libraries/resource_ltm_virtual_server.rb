#
# Author:: Jacob McCann (<jacob.mccann2@target.com>)
# Cookbook Name:: f5-bigip
# Resource:: ltm_virtual_server
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
    # Chef Resource for F5 Virtual Server
    #
    class  F5LtmVirtualServer < Chef::Resource
      PORTS_REGEX ||= /^(6553[0-5]|655[0-2]\d|65[0-4]\d\d|6[0-4]\d{3}|[1-5]\d{4}|[1-9]\d{0,3}|0)$/
      IP_REGEX ||= /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
      # rubocop:disable LineLength
      NM_REGEX ||= /^(((0|128|192|224|240|248|252|254)\.0\.0\.0)|(255\.(0|128|192|224|240|248|252|254)\.0\.0)|(255\.255\.(0|128|192|224|240|248|252|254)\.0)|(255\.255\.255\.(0|128|192|224|240|248|252|254|255)))$/i
      # rubocop:enable LineLength
      PROTOCOLS ||= %w(
        PROTOCOL_ANY
        PROTOCOL_IPV6
        PROTOCOL_ROUTING
        PROTOCOL_NONE
        PROTOCOL_FRAGMENT
        PROTOCOL_DSTOPTS
        PROTOCOL_TCP
        PROTOCOL_UDP
        PROTOCOL_ICMP
        PROTOCOL_ICMPV6
        PROTOCOL_OSPF
        PROTOCOL_SCTP
      )

      VS_TYPES ||= %w(
        RESOURCE_TYPE_POOL
        RESOURCE_TYPE_IP_FORWARDING
        RESOURCE_TYPE_L2_FORWARDING
        RESOURCE_TYPE_REJECT
        RESOURCE_TYPE_FAST_L4
        RESOURCE_TYPE_FAST_HTTP
        RESOURCE_TYPE_STATELESS
      )

      VS_VLANS_STATE ||= %w(
        STATE_ENABLED
        STATE_DISABLED
      )

      VS_TRANSLATE_STATE ||= %w(
        STATE_ENABLED
        STATE_DISABLED
      )

      VS_SNAT_TYPES ||= %w(
        SRC_TRANS_UNKNOWN
        SRC_TRANS_NONE
        SRC_TRANS_AUTOMAP
        SRC_TRANS_SNATPOOL
      )

      attr_accessor :exists, :default_persistence_profile_cnt

      def initialize(name, run_context = nil)
        super
        @resource_name = :f5_ltm_virtual_server
        @provider = Chef::Provider::F5LtmVirtualServer
        @action = :create
        @allowed_actions = [:create, :delete]

        # This is equivalent to setting :name_attribute => true
        @vs_name = name

        # Now we need to set up any resource defaults
        set_defaults
      end

      def vs_name(arg = nil)
        set_or_return(:vs_name, arg, :kind_of => String, :required => true)
      end

      def f5(arg = nil)
        set_or_return(:f5, arg, :kind_of => String, :required => true)
      end

      def destination_address(arg = nil)
        set_or_return(:destination_address, arg, :kind_of => String, :required => true)
      end

      def destination_wildmask(arg = nil)
        set_or_return(:destination_wildmask, arg, :regex => NM_REGEX)
      end

      def source_address(arg = nil)
        set_or_return(:source_address, arg, :kind_of => String, :required => false)
      end

      def destination_port(arg = nil)
        set_or_return(:destination_port, arg, :regex => PORTS_REGEX, :required => true)
      end

      def type(arg = nil)
        set_or_return(:type, arg, :equal_to => VS_TYPES)
      end

      def description(arg = nil)
        set_or_return(:description, arg, :kind_of => String, :required => false)
      end

      def default_pool(arg = nil)
        set_or_return(:default_pool, arg, :kind_of => String, :required => false)
      end

      def protocol(arg = nil)
        set_or_return(:protocol, arg, :equal_to => PROTOCOLS)
      end

      def vlan_state(arg = nil)
        set_or_return(:vlan_state, arg, :equal_to => VS_VLANS_STATE)
      end

      def translate_address(arg = nil)
        set_or_return(:translate_address, arg, :kind_of => [TrueClass, FalseClass])
      end

      def translate_port(arg = nil)
        set_or_return(:translate_port, arg, :kind_of => [TrueClass, FalseClass])
      end

      def vlans(arg = nil)
        set_or_return(:vlans, arg, :kind_of => Array)
      end

      def profiles(arg = nil)
        set_or_return(:profiles, arg, :kind_of => Array)
      end

      def snat_type(arg = nil)
        set_or_return(:snat_type, arg, :equal_to => VS_SNAT_TYPES)
      end

      def snat_pool(arg = nil)
        set_or_return(:snat_pool, arg, :kind_of => String)
      end

      def default_persistence_profile(arg = nil)
        set_or_return(:default_persistence_profile, arg, :kind_of => String)
      end

      def fallback_persistence_profile(arg = nil)
        set_or_return(:fallback_persistence_profile, arg, :kind_of => String)
      end

      def rules(arg = nil)
        set_or_return(:rules, arg, :kind_of => Array)
      end

      def enabled(arg = nil)
        set_or_return(:enabled, arg, :kind_of => [TrueClass, FalseClass])
      end

      private

      def set_defaults # rubocop:disable MethodLength
        @destination_wildmask = '255.255.255.255'
        @type = 'RESOURCE_TYPE_POOL'
        @protocol = 'PROTOCOL_TCP'
        @vlan_state = 'STATE_DISABLED'
        @vlans = []
        @profiles = [{
          'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',
          'profile_name' => '/Common/tcp'
        }]
        @snat_type = 'SRC_TRANS_NONE'
        @snat_pool = ''
        @default_persistence_profile = ''
        @fallback_persistence_profile = ''
        @rules = []
        @enabled = true
        @description = ''
        @translate_address = false
        @translate_port = false
        @source_address = '0.0.0.0/0'
      end
    end
  end
end

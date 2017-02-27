#
# Author:: Jacob McCann (<jacob.mccann2@target.com>)
# Cookbook Name:: f5-bigip
# Resource:: ltm_node
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
    # Chef Resource for F5 LTM Node
    #
    class F5LtmNode < Chef::Resource
      def initialize(name, run_context = nil)
        super
        @resource_name = :f5_ltm_node
        @provider = Chef::Provider::F5LtmNode
        @action = :create
        @allowed_actions = [:create, :delete]

        # This is equivalent to setting :name_attribute => true
        @node_name = name

        # Now we need to set up any resource defaults
        @enabled = true
        @description = 'Created by CHEF'
        @preserve_status = true
      end

      def node_name(arg = nil)
        set_or_return(:node_name, arg, :kind_of => String, :required => true)
      end

      def address(arg = nil)
        # Set to @node_name if not set as a 'default' for backward compatibility
        set_or_return(:address, @node_name, :kind_of => String, :required => true) if @address.nil?

        set_or_return(:address, arg, :kind_of => String, :required => true)
      end

      def f5(arg = nil)
        set_or_return(:f5, arg, :kind_of => String, :required => true)
      end

      def enabled(arg = nil)
        set_or_return(:enabled, arg, :kind_of => [TrueClass, FalseClass])
      end

      def preserve_status(arg = nil)
        set_or_return(:preserve_status, arg, :kind_of => [TrueClass, FalseClass])
      end

      def description(arg = nil)
        set_or_return(:description, arg, :kind_of => String)
      end

      attr_accessor :exists
    end
  end
end

#
# Author:: Sergio Rua <sergio@rua.me.uk>

# Cookbook Name:: f5-bigip
# Resource:: ltm_sslcert
#
# Copyright:: 2015, Sky Betting and Gaming
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
    # Chef Resource for F5 LTM iRule
    #
    class F5LtmSslcert < Chef::Resource
      def initialize(name, run_context = nil)
        super
        @resource_name = :f5_ltm_sslcert
        @provider = Chef::Provider::F5LtmSslcert
        @action = :create
        @allowed_actions = [:create, :delete, :update]

        # This is equivalent to setting :name_attribute => true
        @sslcert_name = name
        @variables = []

        set_defaults
      end

      def sslcert_name(arg = nil)
        set_or_return(:sslcert_name, arg, :kind_of => String, :required => true)
      end

      def key(arg = nil)
        set_or_return(:key, arg, :kind_of => String, :required => false)
      end

      def cert(arg = nil)
        set_or_return(:cert, arg, :kind_of => String, :required => true)
      end

      def mode(arg = nil)
        set_or_return(:mode, arg, :kind_of => String, :required => false)
      end

      def override(arg = nil)
        set_or_return(:variables, arg, :kind_of => [TrueClass, FalseClass], :required => false)
      end

      def f5(arg = nil)
        set_or_return(:f5, arg, :kind_of => String, :required => true)
      end

      attr_accessor :exists_key, :exists_cert, :update_key, :update_cert

      private

      def set_defaults
        @mode = 'MANAGEMENT_MODE_DEFAULT'
        @key = ''
        @cert = ''
        @override = false
      end
    end
  end
end

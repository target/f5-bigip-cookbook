#
# Cookbook Name:: f5-bigip
# Library:: F5::LoadBalancer::Ltm::Monitors::Monitor
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

require 'forwardable'

module F5
  class LoadBalancer
    class Ltm
      class Monitors
        # Monitor template from F5
        class Monitor
          include ::Enumerable
          extend ::Forwardable

          attr_reader :name, :type

          attr_accessor :parent, :interval, :timeout, :directly_usable,
                        :dest_addr_type, :dest_addr_ip, :dest_addr_port

          def_delegators :@data, :[], :[]=, :keys

          def initialize(monitor_soap_map)
            @name = monitor_soap_map['template_name']
            @type = monitor_soap_map['template_type']
            @data = {}
          end

          def user_values
            @data
          end
        end
      end
    end
  end
end

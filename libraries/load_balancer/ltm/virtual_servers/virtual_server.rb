#
# Cookbook Name:: f5-bigip
# Library:: F5::LoadBalancer::Ltm::VirtualServers::VirtualServer
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

module F5
  class LoadBalancer
    class Ltm
      class VirtualServers
        # VirtualServer from F5
        class VirtualServer
          attr_accessor :name, :destination_address, :destination_port, :destination_wildmask,
                        :default_pool, :type, :protocol, :profiles, :status, :vlans,
                        :snat_type, :snat_pool,
                        :default_persistence_profile, :fallback_persistence_profile

          attr_writer :rules

          def initialize(name)
            @name = name
          end

          def enabled
            @status['enabled_status'] == 'ENABLED_STATUS_ENABLED'
          end

          #
          # Sort rules in order of priority and return just the name
          #
          # @return <Array[String]>
          #
          def rules
            return [] if @rules.empty?
            @rules.sort_by { |k| k['priority'] }.map { |h| h['rule_name'] }
          end
        end
      end
    end
  end
end

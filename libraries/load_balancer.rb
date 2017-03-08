#
# Cookbook Name:: f5-bigip
# Library:: F5::LoadBalancer
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

# add currrent dir to load path
$LOAD_PATH << File.dirname(__FILE__)

require 'load_balancer_ltm'

module F5
  # The F5 device
  class LoadBalancer
    attr_accessor :name, :client, :active_folder

    def initialize(name, client)
      @name = name
      @active_folder = client['System.Session'].get_active_folder
      @client = client
    end

    def change_folder(folder = 'Common') # rubocop:disable MethodLength
      folder = if folder.include?('/')
                 folder.split('/')[1]
               else
                 'Common'
               end
      unless @active_folder == folder
        @ltm = nil
        Chef::Log.info "Setting #{folder} as active folder"
        @client['System.Session'].set_active_folder("/#{folder}")
        @active_folder = folder
      end
      true
    end

    #
    # LTM resources for load balancer
    #
    def ltm
      @ltm ||= F5::LoadBalancer::Ltm.new(client)
    end

    #
    # List of device groups the load balancer is a part of
    #
    def device_groups
      @device_groups ||= client['Management.DeviceGroup']
                         .get_list
                         .delete_if { |g| g =~ /device_trust_group/ || g == '/Common/gtm' }
    end

    #
    # Hostname as configured on the F5
    #
    def system_hostname
      @system_hostname ||= client['System.Inet'].get_hostname
    end

    #
    # Return whether the f5 device is active
    #
    def active?
      state == 'FAILOVER_STATE_ACTIVE'
    end

    private

    #
    # Get the failover state of the f5
    #
    def state
      @state ||= client['System.Failover'].get_failover_state
    end
  end
end

#
# Cookbook Name:: f5-bigip
# Library:: F5::LoadBalancer::Ltm::Pools
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

require 'load_balancer/ltm/pools/pool'
require 'load_balancer/ltm/pools/pool/member'
require 'forwardable'

module F5
  class LoadBalancer
    class Ltm
      # A collection of pools.  This Class is an interface for sending bulk
      # updates to F5 for multiple items in a single API call.
      class Pools
        include ::Enumerable
        extend ::Forwardable

        def_delegators :@pools, :find

        def initialize(client)
          @client = client
          refresh_all
        end

        def refresh!(items = [])
          if items.empty?
            refresh_all
            return
          end

          items.each do |item|
            send("refresh_#{item}")
          end
        end

        def all
          @pools
        end

        def pool_names
          @pools.map { |p| p.name }
        end

        # Not currently used but hate to delete code ...
        # def refresh_status
        #   statuses = @client['LocalLB.Pool'].get_object_status(pool_names)
        #
        #   # Pool status
        #   statuses.each_with_index do |status, idx|
        #     @pools[idx].status = status
        #   end
        # end

        def refresh_members
          pools_members = @client['LocalLB.Pool'].get_member_v2(pool_names)

          # No pools to assign members for
          return if pools_members.empty?

          # Convert to collection of PoolMembers
          pools_members.each_with_index do |pool_members, idx|
            pool_members.each { |m| @pools[idx].members << F5::LoadBalancer::Ltm::Pools::Pool::Member.new(m) }
          end

          # Automatically update members states
          # refresh_member_status
        end

        # def refresh_member_status
        #   pool_member_statuses = @client['LocalLB.Pool']
        #                            .get_member_object_status(pool_names, pools_members)
        #
        #   pool_member_statuses.each_with_index do |pool_member_status, idx|
        #     pool_member_status.each_with_index do |member_status, i|
        #       @pools[idx].members[i].status = member_status
        #     end
        #   end
        # end

        def refresh_lb_method
          lb_methods = @client['LocalLB.Pool'].get_lb_method(pool_names)

          lb_methods.each_with_index do |method, idx|
            @pools[idx].lb_method = method
          end
        end

        def refresh_monitors
          # Get Monitor Associations
          values = @client['LocalLB.Pool'].get_monitor_association(pool_names).map { |m| m['monitor_rule'] }
          values.each_with_index { |v, idx| @pools[idx].monitors = v }
        end

        private

        def pools_members
          @pools.map { |p| p.members.map { |m| m.to_hash } }
        end

        def refresh_all
          @pools = @client['LocalLB.Pool'].get_list
                                          .map { |p| F5::LoadBalancer::Ltm::Pools::Pool.new(p) }
          return if @pools.empty?
          refresh_members
          refresh_monitors
          refresh_lb_method
        end
      end
    end
  end
end

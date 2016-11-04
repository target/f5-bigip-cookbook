#
# Cookbook Name:: f5-bigip
# Library:: F5::LoadBalancer::Ltm::Pools::Pool::Member
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
      class Pools
        class Pool
          # Representing an F5 LTM Pool Member
          class Member
            attr_accessor :address, :port, :status

            def initialize(member_hash)
              @address = member_hash['address']
              @port = member_hash['port'].to_s
            end

            def to_hash
              { 'address' => @address, 'port' => @port }
            end
          end
        end
      end
    end
  end
end

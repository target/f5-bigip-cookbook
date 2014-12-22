#
# Cookbook Name:: f5-bigip
# Recipe:: provision_configsync
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

f5s = data_bag(node['f5-bigip']['provisioner']['databag'])

f5s.each do |item|
  f5_config_sync data_bag_item(node['f5-bigip']['provisioner']['databag'], item)['hostname']
end

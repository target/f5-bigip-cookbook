#
# Cookbook Name:: f5-bigip
# Recipe:: provision_delete
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

include_recipe 'f5-bigip::provision_configsync'

f5s = data_bag(node['f5-bigip']['provisioner']['databag'])

f5s.each do |item|
  f5 = data_bag_item(node['f5-bigip']['provisioner']['databag'], item)
  next unless f5.key? 'delete'

  # Delete virtual servers
  if f5['delete'].key? 'virtual_servers'
    f5['delete']['virtual_servers'].each do |vs|
      f5_ltm_virtual_server "#{f5['hostname']}-#{vs}" do
        vs_name vs
        f5 f5['hostname']
        action :delete
        notifies :run, "f5_config_sync[#{f5['hostname']}]", :delayed
      end
    end
  end

  # Delete pools
  if f5['delete'].key? 'pools'
    f5['delete']['pools'].each do |pool|
      f5_ltm_pool "#{f5['hostname']}-#{pool}" do
        pool_name pool
        f5 f5['hostname']
        action :delete
        notifies :run, "f5_config_sync[#{f5['hostname']}]", :delayed
      end
    end
  end

  # Delete monitors
  if f5['delete'].key? 'monitors'
    f5['delete']['monitors'].each do |name|
      f5_ltm_monitor "#{f5['hostname']}-#{name}" do
        monitor_name name
        f5 f5['hostname']
        action :delete
        notifies :run, "f5_config_sync[#{f5['hostname']}]", :delayed
      end
    end
  end

  next unless f5['delete'].key? 'nodes'

  # Delete nodes
  f5['delete']['nodes'].each do |node|
    f5_ltm_node "#{f5['hostname']}-#{node}" do
      node_name node
      f5 f5['hostname']
      action :delete
      notifies :run, "f5_config_sync[#{f5['hostname']}]", :delayed
    end
  end
end

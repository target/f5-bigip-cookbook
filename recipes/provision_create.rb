#
# Cookbook Name:: f5-bigip
# Recipe:: provision_create
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
  next unless f5.key? 'create'

  # Create Nodes
  if f5['create'].key? 'nodes'
    f5['create']['nodes'].each do |name, node|
      f5_ltm_node "#{f5['hostname']}-#{name}" do
        node_name name
        f5 f5['hostname']
        enabled node['enabled']
        notifies :run, "f5_config_sync[#{f5['hostname']}]", :delayed
      end
    end
  end

  # Create monitors
  if f5['create'].key? 'monitors'
    f5['create']['monitors'].each do |name, monitor|
      f5_ltm_monitor "#{f5['hostname']}-#{name}" do
        monitor_name name
        f5 f5['hostname']
        parent monitor['parent'] if check_key_nil(monitor, 'parent')
        interval monitor['interval'] if check_key_nil(monitor, 'interval')
        timeout monitor['timeout'] if check_key_nil(monitor, 'timeout')
        dest_addr_type monitor['dest_addr_type'] if check_key_nil(monitor, 'dest_addr_type')
        dest_addr_ip monitor['dest_addr_ip'] if check_key_nil(monitor, 'dest_addr_ip')
        dest_addr_port monitor['dest_addr_port'] if check_key_nil(monitor, 'dest_addr_port')
        user_values monitor['user_values'] if check_key_nil(monitor, 'user_values')
        notifies :run, "f5_config_sync[#{f5['hostname']}]", :delayed
      end
    end
  end

  # Create pools
  if f5['create'].key? 'pools'
    f5['create']['pools'].each do |name, pool|
      f5_ltm_pool "#{f5['hostname']}-#{name}" do
        pool_name name
        f5 f5['hostname']
        lb_method pool['lb_method']
        monitors pool['monitors']
        members pool['members']
        notifies :run, "f5_config_sync[#{f5['hostname']}]", :delayed
      end
    end
  end

  next unless f5['create'].key? 'virtual_servers'

  # Create virtual servers
  f5['create']['virtual_servers'].each do |name, vs|
    f5_ltm_virtual_server "#{f5['hostname']}-#{name}" do
      vs_name name
      f5 f5['hostname']
      destination_address vs['destination_address']
      destination_port vs['destination_port']
      default_pool vs['default_pool']
      vlan_state vs['vlan_state'] unless vs['vlan_state'].nil?
      vlans vs['vlans'] unless vs['vlans'].nil?
      profiles vs['profiles'] if check_key_nil(vs, 'profiles')
      snat_type vs['snat_type'] if check_key_nil(vs, 'snat_type')
      snat_pool vs['snat_pool'] if check_key_nil(vs, 'snat_pool')
      default_persistence_profile vs['default_persistence_profile'] if check_key_nil(vs, 'default_persistence_profile')
      fallback_persistence_profile vs['fallback_persistence_profile'] if check_key_nil(vs, 'fallback_persistence_profile')
      rules vs['rules'] if check_key_nil(vs, 'rules')
      enabled vs['enabled']
      notifies :run, "f5_config_sync[#{f5['hostname']}]", :delayed
    end
  end
end

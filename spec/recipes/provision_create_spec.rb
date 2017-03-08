require 'spec_helper'

describe 'f5-bigip::provision_create' do
  cached(:chef_run) do
    ChefSpec::ServerRunner.new do |_node, server|
      server.create_data_bag('f5-provisioner',
                             f5_provisioner_databag_data)
    end.converge(described_recipe)
  end

  let(:f5_provisioner_databag_data) do
    {
      'f5-one' => {
        'hostname' => 'f5-one',
        'create' => {
          'nodes' => {
            '10.10.10.10' => { 'enabled' => true },
            '10.10.10.11' => { 'enabled' => false }
          },
          'monitors' => {
            'one' => {
              'parent' => nil
            },
            'two' => {
              'parent' => '/Common/http',
              'interval' => 10,
              'timeout' => 11,
              'dest_addr_type' => 'ATYPE_STAR_ADDRESS',
              'dest_addr_ip' => '12.10.12.10',
              'dest_addr_port' => 1234,
              'user_values' => { 'test' => 'me' }
            }
          },
          'pools' => {
            'default' => {
              'lb_method' => 'LB_METHOD_ROUND_ROBIN',
              'monitors' => %w(http mon_new_defaults)
            },
            'user' => {
              'lb_method' => 'LB_METHOD_ROUND_ROBIN',
              'monitors' => %w(http https),
              'members' => [
                { 'address' => '10.10.10.11', 'port' => 80, 'enabled' => true },
                { 'address' => '10.10.10.12', 'port' => 80, 'enabled' => false }
              ],
              'enabled' => false
            }
          },
          'virtual_servers' => {
            'default-one' => {
              'destination_address' => '10.10.10.10',
              'destination_port' => 80,
              'default_pool' => 'test'
            },
            'default-two' => {
              'destination_address' => '10.10.10.11',
              'destination_port' => 443,
              'default_pool' => 'test2'
            },
            'user-one' => {
              'destination_address' => '10.10.10.10',
              'destination_port' => 80,
              'default_pool' => 'test',
              'vlan_state' => 'STATE_ENABLED',
              'vlans' => ['/Common/vlan123', '/Common/vlan234'],
              'profiles' => [
                { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' },
                { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' }
              ],
              'snat_type' => 'SRC_TRANS_SNATPOOL',
              'snat_pool' => '/Common/snat_pool',
              'default_persistence_profile' => '/Common/test_persistence_profile',
              'fallback_persistence_profile' => '/Common/test2_persistence_profile',
              'rules' => ['/Common/_sys_auth_ldap', '/Common/_sys_auth_radius'],
              'enabled' => false
            },
            'user-two' => {
              'destination_address' => '10.10.10.11',
              'destination_port' => 443,
              'default_pool' => 'test2',
              'vlans' => ['/Common/vlan123', '/Common/vlan234'],
              'profiles' => [
                { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/udp' },
                { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' }
              ],
              'snat_type' => 'SRC_TRANS_AUTOMAP',
              'default_persistence_profile' => '/Common/test2_persistence_profile',
              'fallback_persistence_profile' => '/Common/test_persistence_profile',
              'rules' => ['/Common/_sys_auth_radius', '/Common/_sys_auth_ldap']
            }
          }
        }
      }
    }
  end

  it 'creates a node with default attribute values' do
    expect(chef_run).to create_f5_ltm_node('f5-one-10.10.10.10')
      .with :node_name => '10.10.10.10', :f5 => 'f5-one',
            :enabled => true
    resource = chef_run.f5_ltm_node('f5-one-10.10.10.10')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed
  end

  it 'creates a node with user defined attribute values' do
    expect(chef_run).to create_f5_ltm_node('f5-one-10.10.10.11')
      .with :node_name => '10.10.10.11', :f5 => 'f5-one',
            :enabled => false
    resource = chef_run.f5_ltm_node('f5-one-10.10.10.11')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed
  end

  it 'creates a monitor with default attribute values' do
    expect(chef_run).to create_f5_ltm_monitor('f5-one-one')
      .with :monitor_name => 'one',
            :f5 => 'f5-one',
            :parent => 'https',
            :interval => 5,
            :timeout => 16,
            :dest_addr_type => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT',
            :dest_addr_ip => '0.0.0.0',
            :dest_addr_port => 443,
            :user_values => {}

    resource = chef_run.f5_ltm_monitor('f5-one-one')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed
  end

  it 'creates a monitor with user defined attribute values' do
    expect(chef_run).to create_f5_ltm_monitor('f5-one-two')
      .with :monitor_name => 'two',
            :f5 => 'f5-one',
            :parent => '/Common/http',
            :interval => 10,
            :timeout => 11,
            :dest_addr_type => 'ATYPE_STAR_ADDRESS',
            :dest_addr_ip => '12.10.12.10',
            :dest_addr_port => 1234,
            :user_values => { 'test' => 'me' }

    resource = chef_run.f5_ltm_monitor('f5-one-two')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed
  end

  it 'it creates a pool with default attribute values' do
    expect(chef_run).to create_f5_ltm_pool('f5-one-default')
      .with :pool_name => 'default', :f5 => 'f5-one',
            :monitors => %w(http mon_new_defaults)
    resource = chef_run.f5_ltm_pool('f5-one-default')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed
  end

  it 'it creates a pool with user defined attribute values' do
    expect(chef_run).to create_f5_ltm_pool('f5-one-user')
      .with :pool_name => 'user', :f5 => 'f5-one',
            :monitors => %w(http https),
            :members => [
              { 'address' => '10.10.10.11', 'port' => 80, 'enabled' => true },
              { 'address' => '10.10.10.12', 'port' => 80, 'enabled' => false }
            ]
    resource = chef_run.f5_ltm_pool('f5-one-user')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed
  end

  it 'creates multiple default virtual servers' do
    expect(chef_run).to create_f5_ltm_virtual_server('f5-one-default-one')
      .with :destination_address => '10.10.10.10',
            :destination_port => 80,
            :destination_wildmask => '255.255.255.255',
            :default_pool => 'test', :type => 'RESOURCE_TYPE_POOL',
            :protocol => 'PROTOCOL_TCP',
            :vlan_state => 'STATE_DISABLED', :vlans => [],
            :profiles => [{
              'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',
              'profile_name' => '/Common/tcp'
            }],
            :snat_type => 'SRC_TRANS_NONE', :snat_pool => '',
            :default_persistence_profile => '',
            :fallback_persistence_profile => '',
            :rules => [],
            :enabled => true

    resource = chef_run.f5_ltm_virtual_server('f5-one-default-one')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed

    expect(chef_run).to create_f5_ltm_virtual_server('f5-one-default-two')
      .with :destination_address => '10.10.10.11',
            :destination_port => 443,
            :destination_wildmask => '255.255.255.255',
            :default_pool => 'test2', :type => 'RESOURCE_TYPE_POOL',
            :protocol => 'PROTOCOL_TCP',
            :vlan_state => 'STATE_DISABLED', :vlans => [],
            :profiles => [{
              'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',
              'profile_name' => '/Common/tcp'
            }],
            :snat_type => 'SRC_TRANS_NONE', :snat_pool => '',
            :default_persistence_profile => '',
            :fallback_persistence_profile => '',
            :rules => [],
            :enabled => true

    resource = chef_run.f5_ltm_virtual_server('f5-one-default-two')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed
  end

  it 'creates virtual servers with user defined values' do
    expect(chef_run).to create_f5_ltm_virtual_server('f5-one-user-one')
      .with :destination_address => '10.10.10.10',
            :destination_port => 80,
            :default_pool => 'test',
            :vlan_state => 'STATE_ENABLED',
            :vlans => ['/Common/vlan123', '/Common/vlan234'],
            :profiles => [
              { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' },
              { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' }
            ],
            :snat_type => 'SRC_TRANS_SNATPOOL', :snat_pool => '/Common/snat_pool',
            :default_persistence_profile => '/Common/test_persistence_profile',
            :fallback_persistence_profile => '/Common/test2_persistence_profile',
            :rules => ['/Common/_sys_auth_ldap', '/Common/_sys_auth_radius'],
            :enabled => false

    resource = chef_run.f5_ltm_virtual_server('f5-one-user-one')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed

    expect(chef_run).to create_f5_ltm_virtual_server('f5-one-user-two')
      .with :destination_address => '10.10.10.11',
            :destination_port => 443,
            :default_pool => 'test2',
            :vlan_state => 'STATE_DISABLED',
            :vlans => ['/Common/vlan123', '/Common/vlan234'],
            :profiles => [
              { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/udp' },
              { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' }
            ],
            :snat_type => 'SRC_TRANS_AUTOMAP', :snat_pool => '',
            :default_persistence_profile => '/Common/test2_persistence_profile',
            :fallback_persistence_profile => '/Common/test_persistence_profile',
            :rules => ['/Common/_sys_auth_radius', '/Common/_sys_auth_ldap'],
            :enabled => true

    resource = chef_run.f5_ltm_virtual_server('f5-one-user-two')
    expect(resource).to notify('f5_config_sync[f5-one]').to(:run).delayed
  end
end

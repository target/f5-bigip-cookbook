describe 'testing::overrides' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  it 'creates the proper resources for a vip with default values' do
    config_sync_f5 = chef_run.f5_config_sync('test-f5.test.com')
    expect(config_sync_f5).to do_nothing
    expect(chef_run).to create_f5_ltm_node('test-f5.test.com-10.10.10.10')
      .with(node_name: '10.10.10.10', f5: 'test-f5.test.com', enabled: true)
    expect(chef_run).to create_f5_ltm_node('test-f5.test.com-10.10.10.11')
      .with(node_name: '10.10.10.11', f5: 'test-f5.test.com', enabled: true)
    expect(chef_run).to create_f5_ltm_pool('test-f5.test.com-test-pool')
      .with(pool_name: 'test-pool', f5: 'test-f5.test.com', lb_method: 'LB_METHOD_RATIO_MEMBER',
            monitors: ['/Common/https', '/Common/tcp'],
            members: [{ 'address' => '10.10.10.10', 'port' => 4443, 'enabled' => true },
                      { 'address' => '10.10.10.11', 'port' => 4443, 'enabled' => true }])
    expect(chef_run).to create_f5_ltm_virtual_server('test-f5.test.com-testing')
      .with(vs_name: 'testing', f5: 'test-f5.test.com', destination_address: '192.168.1.10',
            destination_port: 8443, default_pool: 'test-pool',
            vlan_state: 'STATE_ENABLED', vlans: ['/Common/vlan123', '/Common/vlan234'],
            profiles: [
              { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' },
              { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' },
            ],
            snat_type: 'SRC_TRANS_SNATPOOL', snat_pool: '/Common/snat_pool',
            default_persistence_profile: '/Common/test_persistence_profile',
            fallback_persistence_profile: '/Common/test2_persistence_profile',
            rules: ['/Common/_sys_auth_ldap', '/Common/_sys_auth_radius'], enabled: true)
  end
end

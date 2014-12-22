f5_vip 'testing' do
  f5 'test-f5.test.com'
  nodes ['10.10.10.10', '10.10.10.11']
  member_port 4443
  pool 'test-pool'
  lb_method 'LB_METHOD_RATIO_MEMBER'
  monitors ['/Common/https', '/Common/tcp']
  destination_address '192.168.1.10'
  destination_port 8443
  profiles [
    { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' },
    { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' }
  ]
  vlan_state 'STATE_ENABLED'
  vlans ['/Common/vlan123', '/Common/vlan234']
  snat_type 'SRC_TRANS_SNATPOOL'
  snat_pool '/Common/snat_pool'
  default_persistence_profile '/Common/test_persistence_profile'
  fallback_persistence_profile '/Common/test2_persistence_profile'
  rules ['/Common/_sys_auth_ldap', '/Common/_sys_auth_radius']
end

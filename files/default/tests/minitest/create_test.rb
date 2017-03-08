require File.expand_path('../support/helpers', __FILE__)
require 'f5-icontrol'

describe_recipe 'f5-bigip::create' do
  include Helpers::F5Icontrol

  client = nil

  let(:creds) { chef_vault_item(node['f5-bigip']['credentials']['databag'], node['f5-bigip']['credentials']['item']) }
  let(:user) { creds['username'] }
  let(:pass) { creds['password'] }
  let(:hostname) { '192.168.10.19' }
  let(:interfaces) do
    [
      'LocalLB.Monitor',
      'LocalLB.NodeAddressV2',
      'LocalLB.Pool',
      'LocalLB.VirtualServer'
    ]
  end

  it 'can connect to the F5 device' do
    client = F5::IControl.new(hostname, user, pass, interfaces).get_interfaces

    # Query nodes to test connection
    assert client['LocalLB.NodeAddressV2'].get_list,
           'Expected to be able to connect to F5'
  end

  describe 'f5_ltm_node' do
    it 'creates a node' do
      node = '10.10.10.13'
      nodes = client['LocalLB.NodeAddressV2'].get_list.find { |n| n =~ %r{(^|\/)#{node}$} }

      refute_empty nodes, "Node #{node} not created"

      assert true
    end

    it 'creates a node that is enabled' do
      node = '10.10.10.11'
      status = client['LocalLB.NodeAddressV2'].get_object_status([node]).first

      refute_equal 'ENABLED_STATUS_DISABLED', status['enabled_status'],
                   "Expected #{node} to not be ENABLED_STATUS_DISABLED"

      assert true
    end

    it 'creates a node that is disabled' do
      node = '10.10.10.12'
      status = client['LocalLB.NodeAddressV2'].get_object_status([node]).first

      assert_equal 'ENABLED_STATUS_DISABLED', status['enabled_status'],
                   "Expected #{node} to be ENABLED_STATUS_DISABLED"
    end
  end

  describe 'f5_ltm_pool' do
    it "creates a pool called 'new'" do
      pools = client['LocalLB.Pool'].get_list

      result = (pools.include?('/Common/new') || pools.include?('new'))
      assert result,
             "Expected pool 'new' to have been created"
    end

    it "ensures pool 'new' load balance method is roud robin" do
      lb_method = client['LocalLB.Pool'].get_lb_method(['new'])

      result = (lb_method.size == 1 && lb_method.include?('LB_METHOD_ROUND_ROBIN'))
      assert result,
             "Expected pool 'new' load balance method to be LB_METHOD_ROUND_ROBIN"
    end

    it "ensures the pool 'new' health check is https and udp" do
      monitors_association = client['LocalLB.Pool'].get_monitor_association(['new']).first
      monitors = monitors_association['monitor_rule']['monitor_templates']

      # Fail if kind is String as that means there is only 1 associated health monitor
      refute_nil(monitors, "Expected pool 'new' health checks to be https and udp")
      refute_kind_of(String, monitors, "Expected pool 'new' health checks to be https and udp")

      result = (monitors.size == 2 &&
               (monitors.uniq.sort == %w(/Common/https /Common/udp) || monitors.uniq.sort == %w(https udp)))
      assert result,
             "Expected pool 'new' health checks to be https and udp"
    end

    it "ensures the pool 'new' has valid pool members" do
      expecting_members = [
        { 'address' => '/Common/10.10.10.10', 'port' => 80 },
        { 'address' => '/Common/10.10.10.11', 'port' => 80 },
        { 'address' => '/Common/10.10.10.11', 'port' => 8081 }
      ]

      check_pool_members(client, 'new', expecting_members)
    end
  end

  describe 'f5_ltm_virtual_server' do
    it 'creates a virtual server' do
      vs = 'vs_new'
      vs_list = client['LocalLB.VirtualServer'].get_list.find { |v| v =~ %r{(^|\/)#{vs}$} }

      refute_nil vs_list, "Virtual Server #{vs} not created"

      assert true
    end

    it 'creates a virtual server with correct address' do
      check_vs_address(client, 'vs_new', '10.10.10.10')
    end

    it 'creates a virtual server with correct port' do
      check_vs_port(client, 'vs_new', 80)
    end

    it 'creates a virtual server with correct default pool' do
      check_vs_pool(client, 'vs_new', 'new')
    end

    it 'creates a virtual server that is enabled' do
      check_vs_status(client, 'vs_new', true)
    end

    it 'creates a virtual server that is disabled' do
      check_vs_status(client, 'vs_modify', false)
    end

    it 'creates a virtual server that has vlans' do
      check_vs_vlans(client, 'vs_new', ['/Common/vagrant_int'])
    end

    it 'creates a virtual server with default values' do
      exp_profiles = [
        { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' }
      ]

      virtual_servers = F5::LoadBalancer::Ltm::VirtualServers.new(client)

      virtual_server = virtual_servers.find { |m| m.name == '/Common/vs_new' }

      assert arrays_match?(exp_profiles, virtual_server.profiles),
             "Expected profiles of #{exp_profiles.inspect} but got #{virtual_server.profiles.inspect}"
    end

    it 'creates a virtual server with default values' do
      exp_destination_wildmask = '255.255.255.255'
      exp_type = 'RESOURCE_TYPE_POOL'
      exp_protocol = 'PROTOCOL_TCP'
      exp_vlans = { 'state' => 'STATE_DISABLED', 'vlans' => [] }
      exp_enabled = true
      exp_profiles = [{ 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' }]
      exp_snat_type = 'SRC_TRANS_NONE'
      exp_default_persistence_profile = []
      exp_fallback_persistence_profile = ''
      exp_rules = []

      virtual_servers = F5::LoadBalancer::Ltm::VirtualServers.new(client)

      virtual_server = virtual_servers.find { |m| m.name == '/Common/vs_new_defaults' }

      assert_equal exp_destination_wildmask, virtual_server.destination_wildmask
      assert_equal exp_type, virtual_server.type
      assert_equal exp_protocol, virtual_server.protocol
      assert_equal exp_vlans, virtual_server.vlans
      assert_equal exp_enabled, virtual_server.enabled
      assert arrays_match?(exp_profiles, virtual_server.profiles),
             "Expected profiles of #{exp_profiles.inspect} but got #{virtual_server.profiles.inspect}"
      assert_equal exp_snat_type, virtual_server.snat_type
      assert_equal exp_default_persistence_profile, virtual_server.default_persistence_profile
      assert_equal exp_fallback_persistence_profile, virtual_server.fallback_persistence_profile
      assert_equal exp_rules, virtual_server.rules
    end

    it 'creates a virtual server with user values' do
      exp_destination_address = '/Common/11.11.11.0'
      # exp_destination_wildmask = '255.255.255.255' #  Don't currently allow user specified
      exp_destination_port = 443
      # exp_type = 'RESOURCE_TYPE_POOL' # Don't currently allow user specified
      # exp_protocol = 'PROTOCOL_TCP' # Don't currently allow user specified
      exp_vlans = { 'state' => 'STATE_DISABLED', 'vlans' => ['/Common/vagrant_int'] }
      exp_enabled = false
      exp_profiles = [
        { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' },
        { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' },
        { 'profile_context' => 'PROFILE_CONTEXT_TYPE_CLIENT', 'profile_name' => '/Common/clientssl-insecure-compatible' },
        { 'profile_context' => 'PROFILE_CONTEXT_TYPE_SERVER', 'profile_name' => '/Common/serverssl-insecure-compatible' }
      ]
      exp_snat_type = 'SRC_TRANS_AUTOMAP'
      exp_default_persistence_profile = [{ 'profile_name' => '/Common/universal', 'default_profile' => true }]
      exp_fallback_persistence_profile = '/Common/dest_addr'
      exp_rules = ['/Common/_sys_APM_ExchangeSupport_helper', '/Common/_sys_https_redirect']

      virtual_servers = F5::LoadBalancer::Ltm::VirtualServers.new(client)

      virtual_server = virtual_servers.find { |m| m.name == '/Common/vs_new_user_defined' }

      assert_equal exp_destination_address, virtual_server.destination_address
      # assert_equal exp_destination_wildmask, virtual_server.destination_wildmask
      assert_equal exp_destination_port, virtual_server.destination_port
      # assert_equal exp_type, virtual_server.type
      # assert_equal exp_protocol, virtual_server.protocol
      assert_equal exp_vlans, virtual_server.vlans
      assert_equal exp_enabled, virtual_server.enabled
      assert arrays_match?(exp_profiles, virtual_server.profiles),
             "Expected profiles of #{exp_profiles.inspect} but got #{virtual_server.profiles.inspect}"
      assert_equal exp_snat_type, virtual_server.snat_type
      assert_equal exp_default_persistence_profile, virtual_server.default_persistence_profile
      assert_equal exp_fallback_persistence_profile, virtual_server.fallback_persistence_profile
      assert_equal exp_rules, virtual_server.rules
    end
  end

  describe 'f5_ltm_monitor' do
    it 'creates a new monitor templates' do
      exp_monitors = ['/Common/mon_new', '/Common/mon_new_defaults', '/Common/mon_delete'].sort.uniq
      monitors = client['LocalLB.Monitor'].get_template_list.map { |m| m['template_name'] }.sort.uniq

      assert array_contains?(monitors, exp_monitors),
             "Expected monitors of #{exp_monitors.inspect} to be included in #{monitors.inspect}"
    end

    it 'creates a monitor from default values' do
      exp_type = 'TTYPE_HTTPS'
      exp_parent = '/Common/https'
      exp_interval = 5
      exp_timeout = 16
      exp_dest_addr_type = 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT'
      exp_dest_addr_ip = '0.0.0.0'
      exp_dest_addr_port = 443

      monitors = F5::LoadBalancer::Ltm::Monitors.new(client)

      monitor = monitors.find { |m| m.name == '/Common/mon_new_defaults' }

      assert_equal exp_type, monitor.type
      assert_equal exp_parent, monitor.parent
      assert_equal exp_interval, monitor.interval
      assert_equal exp_timeout, monitor.timeout
      assert_equal exp_dest_addr_type, monitor.dest_addr_type
      assert_equal exp_dest_addr_ip, monitor.dest_addr_ip
      assert_equal exp_dest_addr_port, monitor.dest_addr_port
    end

    it 'creates a monitor with user values' do
      exp_type = 'TTYPE_HTTP'
      exp_parent = '/Common/http'
      exp_interval = 10
      exp_timeout = 31
      exp_dest_addr_type = 'ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT'
      exp_dest_addr_ip = '10.0.0.2'
      exp_dest_addr_port = 8080
      exp_user_values = { 'STYPE_SEND' => 'test', 'STYPE_RECEIVE' => 'test_recv' }

      monitors = F5::LoadBalancer::Ltm::Monitors.new(client)

      monitor = monitors.find { |m| m.name == '/Common/mon_new' }

      assert_equal exp_type, monitor.type
      assert_equal exp_parent, monitor.parent
      assert_equal exp_interval, monitor.interval
      assert_equal exp_timeout, monitor.timeout
      assert_equal exp_dest_addr_type, monitor.dest_addr_type
      assert_equal exp_dest_addr_ip, monitor.dest_addr_ip
      assert_equal exp_dest_addr_port, monitor.dest_addr_port
      assert_equal exp_user_values, monitor.user_values
    end
  end
end

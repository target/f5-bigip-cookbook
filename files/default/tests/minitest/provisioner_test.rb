require File.expand_path('../support/helpers', __FILE__)
require 'f5-icontrol'

describe_recipe 'f5-bigip::default' do
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

  it 'creates a client' do
    client = F5::IControl.new(hostname, user, pass, interfaces).get_interfaces
  end

  describe 'f5_ltm_node' do
    it 'enable an existing node' do
      node = '10.10.10.12'
      status = client['LocalLB.NodeAddressV2'].get_object_status([node]).first

      refute_equal 'ENABLED_STATUS_DISABLED', status['enabled_status'],
                   "Expected #{node} to not be ENABLED_STATUS_DISABLED"

      assert true
    end

    it 'disable an existing node' do
      node = '10.10.10.11'
      status = client['LocalLB.NodeAddressV2'].get_object_status([node]).first

      assert_equal 'ENABLED_STATUS_DISABLED', status['enabled_status'],
                   "Expected #{node} to not be ENABLED_STATUS_DISABLED"
    end

    it 'deletes a node' do
      nodes_to_delete = ['10.10.10.13']
      nodelist = client['LocalLB.NodeAddressV2'].get_list.map! { |n| n.gsub('/Common/', '') }

      nodes_missed = nodes_to_delete & nodelist

      assert_empty nodes_missed, "These nodes still exist: #{nodes_missed}. Not deleted?"
    end
  end

  describe 'f5_ltm_pool' do
    it "ensures the pool 'modify' load balance method is round robin" do
      lb_method = client['LocalLB.Pool'].get_lb_method(['modify'])

      assert((lb_method.size == 1 && lb_method.include?('LB_METHOD_ROUND_ROBIN')),
             "Expected pool 'modify' load balance method to be LB_METHOD_ROUND_ROBIN")
    end

    it "ensures the pool 'modify' health check is only http" do
      monitors_association = client['LocalLB.Pool'].get_monitor_association(['modify']).first
      monitors = monitors_association['monitor_rule']['monitor_templates']

      refute_empty(monitors, "Expected pool 'modify' health check to be http")
      refute(monitors.size > 1, "Expected pool 'modify' to have one health check")

      assert((monitors == ['/Common/http'] || monitors == ['http']),
             "Expected pool 'modify' health checks to be http")
    end

    it "ensures the pool 'bad_dns' health checks do not include https" do
      monitors_association = client['LocalLB.Pool'].get_monitor_association(['bad_dns']).first
      monitors = monitors_association['monitor_rule']['monitor_templates']

      # Fail if kind is Array as that means there is more than 1 associated health monitor
      refute_nil(monitors, "Expected pool 'bad_dns' health checks to not be nil")
      if monitors.is_a? Array
        refute_includes(monitors, '/Common/https', "Expected pool 'bad_dns' to not include /Common/https")
        refute_includes(monitors, 'https', "Expected pool 'bad_dns' to not include https")
      elsif monitors.is_a? String
        refute_equal(monitors, '/Common/https', "Expected pool 'bad_dns' to not be /Common/https")
        refute_equal(monitors, 'https', "Expected pool 'bad_dns' to not be https")
      else
        flunk("Expected monitors kind_of String or Array, not #{monitors.class}")
      end

      # If not refuted up to this point, pass
      assert true
    end

    it "ensures the pool 'bad_dns' health checks includes udp" do
      monitors_association = client['LocalLB.Pool'].get_monitor_association(['bad_dns']).first
      monitors = monitors_association['monitor_rule']['monitor_templates']

      # Fail if kind is Array as that means there is more than 1 associated health monitor
      refute_nil(monitors, "Expected pool 'bad_dns' health checks to not be nil")

      # Check format of monitor string
      monitor_string_check = monitors
      monitor_string_check = monitors.first if monitors.is_a? Array
      monitor_check = 'udp'
      monitor_check = '/Common/udp' if monitor_string_check.include? '/Common/'

      if monitors.is_a? Array
        assert_includes(monitors, monitor_check, "Expected pool 'bad_dns' to include udp")
      elsif monitors.is_a? String
        assert_equal(monitors, monitor_check, "Expected pool 'bad_dns' to be udp")
      else
        flunk("Expected monitors kind_of String or Array, not #{monitors.class}")
      end
    end

    it "ensure the pool 'modify' has a new member" do
      expecting_member = { 'address' => '/Common/10.10.10.10', 'port' => 80 }

      check_pool_member(client, 'modify', expecting_member)
    end

    it 'deletes a pool' do
      pools_to_delete = ['delete2']
      poollist = client['LocalLB.Pool'].get_list.map! { |n| n.gsub('/Common/', '') }

      pools_missed = pools_to_delete & poollist

      assert_empty pools_missed, "These pools still exist: #{pools_missed}. Not deleted?"
    end
  end

  describe 'f5_ltm_virtual_server' do
    it 'updates a virtual servers default pool' do
      check_vs_pool(client, 'vs_modify', 'modify')
    end

    it 'updates a virtual server with correct address' do
      check_vs_address(client, 'vs_modify', '10.10.10.12')
    end

    it 'updates a virtual server with correct port' do
      check_vs_port(client, 'vs_modify', 443)
    end

    it 'updates a virtual servers state' do
      check_vs_status(client, 'vs_modify', true)
    end

    it 'disables vlans on a virtual server' do
      check_vs_vlan_state(client, 'vs_new', 'STATE_DISABLED')
    end

    it 'deletes a virtual server' do
      vs_to_delete = ['vs_delete']
      vs_list = client['LocalLB.VirtualServer'].get_list.map! { |v| v.gsub('/Common/', '') }

      vs_missed = vs_to_delete & vs_list

      assert_empty vs_missed, "These virtual servers still exist: #{vs_missed}. Not deleted?"
    end

    it 'modifies an existing virtual server' do
      exp_profiles = [
        { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' }
      ]

      virtual_servers = F5::LoadBalancer::Ltm::VirtualServers.new(client)

      virtual_server = virtual_servers.find { |m| m.name == '/Common/vs_modify' }

      assert arrays_match?(exp_profiles, virtual_server.profiles),
             "Expected profiles of #{exp_profiles.inspect} but got #{virtual_server.profiles.inspect}"
    end

    it 'adds stuff to the virtual server with default values' do
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
      exp_default_persistence_profile = [{ 'profile_name' => '/Common/ssl', 'default_profile' => true }]
      exp_fallback_persistence_profile = '/Common/source_addr'
      exp_rules = ['/Common/_sys_https_redirect', '/Common/_sys_APM_ExchangeSupport_helper']

      virtual_servers = F5::LoadBalancer::Ltm::VirtualServers.new(client)

      virtual_server = virtual_servers.find { |m| m.name == '/Common/vs_new_defaults' }

      # assert_equal exp_destination_address, virtual_server.destination_address
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

    it 'removes stuff from the virtual server with user values' do
      # exp_destination_wildmask = '255.255.255.255' #  Don't currently allow user specified
      exp_destination_port = 80
      # exp_type = 'RESOURCE_TYPE_POOL' # Don't currently allow user specified
      # exp_protocol = 'PROTOCOL_TCP' # Don't currently allow user specified
      exp_vlans = { 'state' => 'STATE_DISABLED', 'vlans' => [] }
      exp_enabled = true
      exp_profiles = [
        { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' }
      ]
      exp_snat_type = 'SRC_TRANS_NONE'
      exp_default_persistence_profile = []
      exp_fallback_persistence_profile = ''
      exp_rules = []

      virtual_servers = F5::LoadBalancer::Ltm::VirtualServers.new(client)

      virtual_server = virtual_servers.find { |m| m.name == '/Common/vs_new_user_defined' }

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
    it 'modifies an existing monitor' do
      exp_type = 'TTYPE_HTTP'
      exp_parent = '/Common/http'
      exp_interval = 11
      exp_timeout = 34
      exp_dest_addr_type = 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT'
      exp_dest_addr_ip = '0.0.0.0'
      exp_dest_addr_port = 8081

      monitors = F5::LoadBalancer::Ltm::Monitors.new(client)

      monitor = monitors.find { |m| m.name == '/Common/mon_new' }

      assert_equal exp_type, monitor.type
      assert_equal exp_parent, monitor.parent
      assert_equal exp_interval, monitor.interval
      assert_equal exp_timeout, monitor.timeout
      assert_equal exp_dest_addr_type, monitor.dest_addr_type
      assert_equal exp_dest_addr_ip, monitor.dest_addr_ip
      assert_equal exp_dest_addr_port, monitor.dest_addr_port
    end

    it 'deletes a monitor template' do
      monitors_to_delete = ['mon_delete']
      monitors = client['LocalLB.Monitor'].get_template_list.map! { |m| m['template_name'].gsub('/Common/', '') }
      monitors_missed = monitors_to_delete & monitors
      assert_empty monitors_missed, "These virtual servers still exist: #{monitors_missed}. Not deleted?"
    end
  end
end

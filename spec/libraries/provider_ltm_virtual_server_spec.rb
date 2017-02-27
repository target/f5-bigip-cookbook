require 'spec_helper'

require 'chef/platform'
require 'chef/run_context'
require 'chef/resource'
require 'chef/event_dispatch/base'
require 'chef/event_dispatch/dispatcher'

require 'resource_ltm_virtual_server'

describe Chef::Provider::F5LtmVirtualServer do
  # Create a provider instance
  let(:provider) { Chef::Provider::F5LtmVirtualServer.new(new_resource, run_context) }

  # LoadBalancer stubbing
  let(:load_balancer) { double('F5::LoadBalancer', :client => client) }
  let(:client) do
    {
      'LocalLB.VirtualServer' => locallb_virtual_server
    }
  end
  let(:locallb_virtual_server) { double('LocalLB.VirtualServer') }

  # Some Chef stubbing
  let(:node) do
    node = Chef::Node.new
    node
  end
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }

  # Set current_resource and new_resource state
  let(:new_resource) do
    r = Chef::Resource::F5LtmVirtualServer.new('test_virtual_server')
    r.f5('test')
    r.default_pool('test_pool')
    r.destination_address('10.10.10.11')
    r.destination_port(80)
    r
  end
  let(:current_resource) do
    r = Chef::Resource::F5LtmVirtualServer.new('test_virtual_server')
    r.exists = true
    r.default_pool('test_pool')
    r.destination_address('10.10.10.11')
    r.destination_port(80)
    r.default_persistence_profile_cnt = 1
    r
  end

  # Tie some things together
  before do
    allow(provider).to receive(:load_current_resource).and_return(current_resource)
    allow(provider).to receive(:load_balancer).and_return(load_balancer)
    provider.new_resource = new_resource
    provider.current_resource = current_resource
  end

  describe '#action_create' do
    describe 'with default values' do
      it 'creates a new virtual server if not already created' do
        provider.current_resource.exists = false
        expect(locallb_virtual_server).to receive(:create)
          .with([{ 'name' => 'test_virtual_server',
                   'address' => '10.10.10.11',
                   'port' => 80, 'protocol' => 'PROTOCOL_TCP' }],
                ['255.255.255.255'],
                [{ 'type' => 'RESOURCE_TYPE_POOL',
                   'default_pool_name' => 'test_pool' }],
                [[{ 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' }]])
        provider.action_create
      end

      it 'does nothing if virtual server is already created' do
        expect(locallb_virtual_server).not_to receive(:create)
        provider.action_create
      end
    end

    describe 'with user values' do
      before do
        provider.new_resource.destination_wildmask('255.255.255.0')
        # provider.new_resource.type('RESOURCE_TYPE_POOL') # Don't manage yet
        # provider.new_resource.protocol('PROTOCOL_TCP') # Don't manage yet
        provider.new_resource.vlan_state('STATE_ENABLED')
        provider.new_resource.vlans(['/Common/test2', '/Common/test2'])
        provider.new_resource.profiles(
          [{
            'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',
            'profile_name' => '/Common/tcp'
          }, {
            'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',
            'profile_name' => '/Common/http'
          }]
        )
        provider.new_resource.snat_type('SRC_TRANS_SNATPOOL')
        provider.new_resource.snat_pool('/Common/test_snat_pool')
        provider.new_resource.default_persistence_profile('/Common/test_persistence')
        provider.new_resource.fallback_persistence_profile('/Common/test_fallback_persistence')
        provider.new_resource.rules(['/Common/rule1', '/Common/rule2'])
        provider.new_resource.enabled(false)
      end

      it 'creates a new virtual server if not already created' do
        provider.current_resource.exists = false
        expect(locallb_virtual_server).to receive(:create)
          .with([{ 'name' => 'test_virtual_server',
                   'address' => '10.10.10.11',
                   'port' => 80, 'protocol' => 'PROTOCOL_TCP' }],
                ['255.255.255.0'],
                [{ 'type' => 'RESOURCE_TYPE_POOL',
                   'default_pool_name' => 'test_pool' }],
                [[{ 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' },
                  { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' }]])
        expect(locallb_virtual_server).to receive(:remove_all_rules).with(['test_virtual_server'])
        expect(locallb_virtual_server).to receive(:set_enabled_state).with(['test_virtual_server'], ['STATE_DISABLED'])
        expect(locallb_virtual_server).to receive(:set_vlan)
          .with(['test_virtual_server'],
                [{ 'state' => 'STATE_ENABLED',
                   'vlans' => ['/Common/test2', '/Common/test2'] }])
        expect(locallb_virtual_server).to receive(:set_snat_pool).with(['test_virtual_server'], ['/Common/test_snat_pool'])
        expect(locallb_virtual_server).to receive(:set_fallback_persistence_profile)
          .with(['test_virtual_server'], [''])
        expect(locallb_virtual_server).to receive(:remove_all_persistence_profiles).with(['test_virtual_server'])
        expect(locallb_virtual_server).to receive(:add_persistence_profile)
          .with(['test_virtual_server'],
                [[{ 'profile_name' => '/Common/test_persistence', 'default_profile' => 'true' }]])
        expect(locallb_virtual_server).to receive(:set_fallback_persistence_profile)
          .with(['test_virtual_server'], ['/Common/test_fallback_persistence'])
        expect(locallb_virtual_server).to receive(:add_rule)
          .with(['test_virtual_server'],
                [[{ 'rule_name' => '/Common/rule1', 'priority' => 1 },
                  { 'rule_name' => '/Common/rule2', 'priority' => 2 }]])
        provider.action_create
      end

      it 'does nothing if virtual server is already created' do
        provider.current_resource.destination_wildmask('255.255.255.0')
        # provider.current_resource.type('RESOURCE_TYPE_POOL') # Don't manage yet
        # provider.current_resource.protocol('PROTOCOL_TCP') # Don't manage yet
        provider.current_resource.vlan_state('STATE_ENABLED')
        provider.current_resource.vlans(['/Common/test2', '/Common/test2'])
        provider.current_resource.profiles(
          [{
            'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',
            'profile_name' => '/Common/tcp'
          }, {
            'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',
            'profile_name' => '/Common/http'
          }]
        )
        provider.current_resource.snat_type('SRC_TRANS_SNATPOOL')
        provider.current_resource.snat_pool('/Common/test_snat_pool')
        provider.current_resource.default_persistence_profile('/Common/test_persistence')
        provider.current_resource.fallback_persistence_profile('/Common/test_fallback_persistence')
        provider.current_resource.rules(['/Common/rule1', '/Common/rule2'])
        provider.current_resource.enabled(false)

        expect(locallb_virtual_server).not_to receive(:create)
        provider.action_create
      end
    end

    describe 'managing vlans' do
      it 'sets to correct vlan state' do
        provider.new_resource.vlan_state('STATE_ENABLED')
        expect(locallb_virtual_server).to receive(:set_vlan)
          .with(['test_virtual_server'],
                [{ 'state' => 'STATE_ENABLED',
                   'vlans' => [] }])
        provider.action_create
      end

      it 'does not update vlan state if already correct' do
        provider.new_resource.vlan_state('STATE_ENABLED')
        provider.current_resource.vlan_state('STATE_ENABLED')
        expect(locallb_virtual_server).not_to receive(:set_vlan)
        provider.action_create
      end

      it 'associates the correct vlans' do
        provider.new_resource.vlans(['/Common/test2', '/Common/test2'])
        expect(locallb_virtual_server).to receive(:set_vlan)
          .with(['test_virtual_server'],
                [{ 'state' => 'STATE_DISABLED',
                   'vlans' => ['/Common/test2', '/Common/test2'] }])
        provider.action_create
      end

      it 'does not associate vlans if already correct' do
        provider.new_resource.vlans(['/Common/test2', '/Common/test2'])
        provider.current_resource.vlans(['/Common/test2', '/Common/test2'])
        expect(locallb_virtual_server).not_to receive(:set_vlan)
        provider.action_create
      end
    end

    describe 'managing pool' do
      it 'sets to correct pool' do
        provider.new_resource.default_pool('test_pool_new')
        expect(locallb_virtual_server).to receive(:set_default_pool_name)
          .with(['test_virtual_server'], ['test_pool_new'])
        provider.action_create
      end

      it 'does not update pool if already correct' do
        provider.new_resource.default_pool('test_pool_new')
        provider.current_resource.default_pool('test_pool_new')
        expect(locallb_virtual_server).not_to receive(:set_default_pool_name)
        provider.action_create
      end
    end

    describe 'managing address' do
      it 'sets to correct address' do
        provider.new_resource.destination_address('10.10.10.12')
        expect(locallb_virtual_server).to receive(:set_destination_v2)
          .with(['test_virtual_server'], [{ 'address' => '10.10.10.12', 'port' => 80 }])
        provider.action_create
      end

      it 'does not update address if already correct' do
        provider.new_resource.destination_address('10.10.10.12')
        provider.current_resource.destination_address('10.10.10.12')
        expect(locallb_virtual_server).not_to receive(:set_destination_v2)
        provider.action_create
      end

      it 'sets to correct port' do
        provider.new_resource.destination_port(443)
        expect(locallb_virtual_server).to receive(:set_destination_v2)
          .with(['test_virtual_server'], [{ 'address' => '10.10.10.11', 'port' => 443 }])
        provider.action_create
      end

      it 'does not update port if already correct' do
        provider.new_resource.destination_port(443)
        provider.current_resource.destination_port(443)
        expect(locallb_virtual_server).not_to receive(:set_destination_v2)
        provider.action_create
      end

      it 'sets to correct wildmask' do
        provider.new_resource.destination_wildmask('255.255.255.0')
        expect(locallb_virtual_server).to receive(:set_wildmask).with(['test_virtual_server'], ['255.255.255.0'])
        provider.action_create
      end

      it 'does not update wildmask if already correct' do
        provider.new_resource.destination_wildmask('255.255.255.0')
        provider.current_resource.destination_wildmask('255.255.255.0')
        expect(locallb_virtual_server).not_to receive(:set_wildmask)
        provider.action_create
      end
    end

    describe 'managing rules' do
      it 'adds new rules' do
        provider.new_resource.rules(['/Common/rule2', '/Common/rule1'])
        expect(locallb_virtual_server).to receive(:remove_all_rules).with(['test_virtual_server'])
        expect(locallb_virtual_server).to receive(:add_rule)
          .with(['test_virtual_server'],
                [[{ 'rule_name' => '/Common/rule2', 'priority' => 1 },
                  { 'rule_name' => '/Common/rule1', 'priority' => 2 }]])
        provider.action_create
      end

      it 'removes extra rules' do
        provider.current_resource.rules(['/Common/rule2', '/Common/rule1', '/Common/rule3'])
        provider.new_resource.rules(['/Common/rule2', '/Common/rule1'])
        expect(locallb_virtual_server).to receive(:remove_all_rules).with(['test_virtual_server'])
        expect(locallb_virtual_server).to receive(:add_rule)
          .with(['test_virtual_server'],
                [[{ 'rule_name' => '/Common/rule2', 'priority' => 1 },
                  { 'rule_name' => '/Common/rule1', 'priority' => 2 }]])
        provider.action_create
      end

      it 'puts rules in correct order' do
        provider.current_resource.rules(['/Common/rule1', '/Common/rule2'])
        provider.new_resource.rules(['/Common/rule2', '/Common/rule1'])
        expect(locallb_virtual_server).to receive(:remove_all_rules).with(['test_virtual_server'])
        expect(locallb_virtual_server).to receive(:add_rule)
          .with(['test_virtual_server'],
                [[{ 'rule_name' => '/Common/rule2', 'priority' => 1 },
                  { 'rule_name' => '/Common/rule1', 'priority' => 2 }]])
        provider.action_create
      end

      it 'does not update address if already correct' do
        provider.current_resource.rules(['/Common/rule2', '/Common/rule1'])
        provider.new_resource.rules(['/Common/rule2', '/Common/rule1'])
        expect(locallb_virtual_server).not_to receive(:remove_all_rules).with(['test_virtual_server'])
        expect(locallb_virtual_server).not_to receive(:add_rule)
        provider.action_create
      end
    end

    describe 'managing snat' do
      it 'sets snat type none' do
        provider.current_resource.snat_type('SRC_TRANS_AUTOMAP')
        provider.new_resource.snat_type('SRC_TRANS_NONE')
        expect(locallb_virtual_server).to receive(:set_snat_none).with(['test_virtual_server'])
        provider.action_create
      end

      it 'sets snat type automap' do
        provider.current_resource.snat_type('SRC_TRANS_NONE')
        provider.new_resource.snat_type('SRC_TRANS_AUTOMAP')
        expect(locallb_virtual_server).to receive(:set_snat_automap).with(['test_virtual_server'])
        provider.action_create
      end

      it 'sets snat pool' do
        provider.current_resource.snat_type('SRC_TRANS_NONE')
        provider.new_resource.snat_type('SRC_TRANS_SNATPOOL')
        provider.new_resource.snat_pool('/Common/snat_pool')
        expect(locallb_virtual_server).to receive(:set_snat_pool).with(['test_virtual_server'], ['/Common/snat_pool'])
        provider.action_create
      end

      it 'makes no updates if snat type and pool are set' do
        provider.current_resource.snat_type('SRC_TRANS_SNATPOOL')
        provider.current_resource.snat_pool('/Common/snat_pool')
        provider.new_resource.snat_type('SRC_TRANS_SNATPOOL')
        provider.new_resource.snat_pool('/Common/snat_pool')
        expect(locallb_virtual_server).not_to receive(:set_snat_pool)
        expect(locallb_virtual_server).not_to receive(:set_snat_automap)
        expect(locallb_virtual_server).not_to receive(:set_snat_none)
        provider.action_create
      end
    end

    describe 'managing profiles' do
      let(:default_profiles) do
        [{
          'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',
          'profile_name' => '/Common/tcp'
        }]
      end
      let(:some_profiles) do
        [
          { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' },
          { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' }
        ]
      end
      let(:lots_profiles) do
        [
          { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' },
          { 'profile_context' => 'PROFILE_CONTEXT_TYPE_CLIENT', 'profile_name' => '/Common/clientssl-insecure-compatible' },
          { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' },
          { 'profile_context' => 'PROFILE_CONTEXT_TYPE_SERVER', 'profile_name' => '/Common/serverssl-insecure-compatible' }
        ]
      end

      it 'add new profiles' do
        provider.current_resource.profiles(default_profiles)
        provider.new_resource.profiles(some_profiles)
        expect(locallb_virtual_server).to receive(:remove_all_rules).with(['test_virtual_server'])
        expect(locallb_virtual_server).to receive(:add_profile)
          .with(['test_virtual_server'],
                [[{ 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' }]])
        provider.action_create
      end

      it 'removes extra profiles' do
        provider.current_resource.profiles(lots_profiles)
        provider.new_resource.profiles(default_profiles)
        expect(locallb_virtual_server).to receive(:remove_all_rules).with(['test_virtual_server'])
        expect(locallb_virtual_server).to receive(:remove_profile).with(
          ['test_virtual_server'],
          [[
            { 'profile_context' => 'PROFILE_CONTEXT_TYPE_CLIENT', 'profile_name' => '/Common/clientssl-insecure-compatible' },
            { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' },
            { 'profile_context' => 'PROFILE_CONTEXT_TYPE_SERVER', 'profile_name' => '/Common/serverssl-insecure-compatible' }
          ]]
        )
        provider.action_create
      end

      it 'does nothing if profiles set' do
        provider.current_resource.profiles(lots_profiles)
        provider.new_resource.profiles(lots_profiles)
        expect(locallb_virtual_server).not_to receive(:remove_all_rules)
        expect(locallb_virtual_server).not_to receive(:add_profile)
        expect(locallb_virtual_server).not_to receive(:remove_profile)
        provider.action_create
      end
    end

    describe 'managing enable state' do
      it 'sets state to enabled' do
        provider.current_resource.enabled(false)
        provider.new_resource.enabled(true)
        expect(locallb_virtual_server).to receive(:set_enabled_state).with(['test_virtual_server'], ['STATE_ENABLED'])
        provider.action_create
      end

      it 'sets state to disabled' do
        provider.new_resource.enabled(false)
        expect(locallb_virtual_server).to receive(:set_enabled_state).with(['test_virtual_server'], ['STATE_DISABLED'])
        provider.action_create
      end

      it 'does nothing if state is set' do
        provider.current_resource.enabled(false)
        provider.new_resource.enabled(false)
        expect(locallb_virtual_server).not_to receive(:set_enabled_state)
        provider.action_create
      end
    end

    describe 'managing persistence profiles' do
      it 'sets default persistence profile' do
        provider.new_resource.default_persistence_profile('/Common/test_persistence')
        expect(locallb_virtual_server).to receive(:set_fallback_persistence_profile).with(['test_virtual_server'], [''])
        expect(locallb_virtual_server).to receive(:remove_all_persistence_profiles).with(['test_virtual_server'])
        expect(locallb_virtual_server).to receive(:add_persistence_profile)
          .with(['test_virtual_server'],
                [[{ 'profile_name' => '/Common/test_persistence', 'default_profile' => 'true' }]])
        provider.action_create
      end

      it 'removes default persistence_profile' do
        provider.current_resource.default_persistence_profile('/Common/test_persistence')
        provider.new_resource.default_persistence_profile('')
        expect(locallb_virtual_server).to receive(:set_fallback_persistence_profile).with(['test_virtual_server'], [''])
        expect(locallb_virtual_server).to receive(:remove_all_persistence_profiles).with(['test_virtual_server'])
        provider.action_create
      end

      it 'sets fallback persistence profile' do
        provider.current_resource.default_persistence_profile('/Common/test_persistence')
        provider.new_resource.default_persistence_profile('/Common/test_persistence')
        provider.new_resource.fallback_persistence_profile('/Common/test_fallback_persistence')
        expect(locallb_virtual_server).to receive(:set_fallback_persistence_profile).with(['test_virtual_server'], ['/Common/test_fallback_persistence'])
        provider.action_create
      end

      it 'removes fallback persistence profile' do
        provider.current_resource.default_persistence_profile('/Common/test_persistence')
        provider.current_resource.fallback_persistence_profile('/Common/test_fallback_persistence')
        provider.new_resource.default_persistence_profile('/Common/test_persistence')
        provider.new_resource.fallback_persistence_profile('')
        expect(locallb_virtual_server).to receive(:set_fallback_persistence_profile).with(['test_virtual_server'], [''])
        provider.action_create
      end

      it 'does nothing if persistence profiles are set' do
        provider.current_resource.default_persistence_profile('/Common/test_persistence')
        provider.current_resource.fallback_persistence_profile('/Common/test_fallback_persistence')
        provider.new_resource.default_persistence_profile('/Common/test_persistence')
        provider.new_resource.fallback_persistence_profile('/Common/test_fallback_persistence')
        expect(locallb_virtual_server).not_to receive(:set_fallback_persistence_profile).with(['test_virtual_server'], [''])
        expect(locallb_virtual_server).not_to receive(:remove_all_persistence_profiles).with(['test_virtual_server'])
        expect(locallb_virtual_server).not_to receive(:add_persistence_profile)
        provider.action_create
      end
    end
  end
end

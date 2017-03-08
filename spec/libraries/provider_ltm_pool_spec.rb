require 'spec_helper'

require 'chef/platform'
require 'chef/run_context'
require 'chef/resource'
require 'chef/event_dispatch/base'
require 'chef/event_dispatch/dispatcher'

require 'resource_ltm_pool'

describe Chef::Provider::F5LtmPool do
  # Create a provider instance
  let(:provider) { Chef::Provider::F5LtmPool.new(new_resource, run_context) }

  # LoadBalancer stubbing
  let(:load_balancer) { double('F5::LoadBalancer', :client => client) }
  let(:client) do
    {
      'LocalLB.Pool' => locallb_pool
    }
  end
  let(:locallb_pool) { double('LocalLB.Pool') }

  # Some Chef stubbing
  let(:node) do
    node = Chef::Node.new
    node
  end
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }

  # Set current_resource and new_resource state
  let(:new_resource) do
    r = Chef::Resource::F5LtmPool.new('test_pool')
    r.f5('test')
    r
  end
  let(:current_resource) { Chef::Resource::F5LtmPool.new('test_pool') }

  let(:pool_members) do
    [
      { 'address' => '10.10.10.11', 'port' => 80, 'enabled' => true },
      { 'address' => '10.10.10.11', 'port' => 8081, 'enabled' => false },
      { 'address' => '10.10.10.10', 'port' => 80, 'enabled' => true }
    ]
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
      it 'creates a new pool if not already created' do
        expect(locallb_pool).to receive(:create_v2)
          .with(['test_pool'], ['LB_METHOD_ROUND_ROBIN'], [[]])
        provider.action_create
      end

      it 'does nothing if pool is already created' do
        provider.current_resource.exists = true
        expect(locallb_pool).not_to receive(:create_v2)
        provider.action_create
      end
    end

    describe 'with user values' do
      before do
        provider.new_resource.lb_method('LB_METHOD_RATIO_MEMBER')
        provider.new_resource.monitors(['/Common/https', '/Common/tcp'])
        provider.new_resource.members(pool_members)
      end

      it 'creates a new pool if not already created' do
        expect(locallb_pool).to receive(:create_v2)
          .with(['test_pool'],
                ['LB_METHOD_RATIO_MEMBER'],
                [[
                  { 'address' => '10.10.10.11', 'port' => 80 },
                  { 'address' => '10.10.10.11', 'port' => 8081 },
                  { 'address' => '10.10.10.10', 'port' => 80 }
                ]])
        expect(locallb_pool).to receive(:set_monitor_association).with(
          [{
            'pool_name' => 'test_pool',
            'monitor_rule' => {
              'type' => 'MONITOR_RULE_TYPE_AND_LIST',
              'quorum' => 0,
              'monitor_templates' => ['/Common/https', '/Common/tcp']
            }
          }]
        )
        provider.action_create
      end

      it 'does nothing if pool is already created' do
        provider.current_resource.exists = true
        provider.current_resource.lb_method('LB_METHOD_RATIO_MEMBER')
        provider.current_resource.monitors(['/Common/https', '/Common/tcp'])
        provider.current_resource.members(pool_members)
        expect(locallb_pool).not_to receive(:create_v2)
        expect(locallb_pool).not_to receive(:set_monitor_association)
        provider.action_create
      end
    end

    it 'adds missing pool members' do
      provider.current_resource.exists = true
      provider.current_resource.members(
        [
          { 'address' => '10.10.10.10', 'port' => '80' },
          { 'address' => '10.10.10.11', 'port' => '8081' }
        ]
      )
      provider.new_resource.members(pool_members)
      expect(locallb_pool).to receive(:add_member_v2)
        .with(['test_pool'],
              [[{ 'address' => '10.10.10.11', 'port' => '80' }]])
      provider.action_create
    end

    # Need to implement
    # it 'removes extra pool members' do
    #   provider.current_resource.exists = true
    #   provider.current_resource.members(pool_members)
    #   provider.new_resource.members([
    #     { 'address' => '10.10.10.10', 'port' => '80' },
    #     { 'address' => '10.10.10.11', 'port' => '80' }])
    #   expect(locallb_pool).to receive(:remove_member_v2)
    #                           .with(['test_pool'],
    #                                 [[{ 'address' => '10.10.10.11', 'port' => '8081' }]])
    #   provider.action_create
    # end

    it 'does nothing to matching pool members' do
      provider.current_resource.exists = true
      provider.current_resource.members(pool_members)
      provider.new_resource.members(pool_members)
      expect(locallb_pool).not_to receive(:add_member_v2)
      expect(locallb_pool).not_to receive(:remove_member_v2)
      provider.action_create
    end

    it 'updates improperly set LB Method' do
      provider.current_resource.exists = true
      provider.current_resource.lb_method('LB_METHOD_ROUND_ROBIN')
      provider.new_resource.lb_method('LB_METHOD_RATIO_MEMBER')
      expect(locallb_pool).to receive(:set_lb_method)
        .with(['test_pool'], ['LB_METHOD_RATIO_MEMBER'])
      provider.action_create
    end

    it 'does not update properly set LB Method' do
      provider.current_resource.exists = true
      provider.current_resource.lb_method('LB_METHOD_RATIO_MEMBER')
      provider.new_resource.lb_method('LB_METHOD_RATIO_MEMBER')
      expect(locallb_pool).not_to receive(:set_lb_method)
      provider.action_create
    end

    it 'removes improperly associated pool monitors' do
      provider.current_resource.exists = true
      provider.current_resource.monitors(['/Common/http', '/Common/https'])
      provider.new_resource.monitors([])
      expect(locallb_pool).to receive(:set_monitor_association).with(
        [{
          'pool_name' => 'test_pool',
          'monitor_rule' => {
            'type' => 'MONITOR_RULE_TYPE_NONE',
            'quorum' => 0,
            'monitor_templates' => []
          }
        }]
      )
      provider.action_create
    end

    it 'updates improperly associated single pool monitor' do
      provider.current_resource.exists = true
      provider.current_resource.monitors(['/Common/http', '/Common/https'])
      provider.new_resource.monitors(['/Common/https'])
      expect(locallb_pool).to receive(:set_monitor_association).with(
        [{
          'pool_name' => 'test_pool',
          'monitor_rule' => {
            'type' => 'MONITOR_RULE_TYPE_SINGLE',
            'quorum' => 0,
            'monitor_templates' => ['/Common/https']
          }
        }]
      )
      provider.action_create
    end

    it 'updates improperly associated multiple pool monitors' do
      provider.current_resource.exists = true
      provider.current_resource.monitors(['/Common/https'])
      provider.new_resource.monitors(['/Common/https', '/Common/tcp'])
      expect(locallb_pool).to receive(:set_monitor_association).with(
        [{
          'pool_name' => 'test_pool',
          'monitor_rule' => {
            'type' => 'MONITOR_RULE_TYPE_AND_LIST',
            'quorum' => 0,
            'monitor_templates' => ['/Common/https', '/Common/tcp']
          }
        }]
      )
      provider.action_create
    end

    it 'does not update properly associated pool monitors' do
      provider.current_resource.exists = true
      provider.current_resource.monitors(['/Common/https'])
      provider.new_resource.monitors(['/Common/https'])
      expect(locallb_pool).not_to receive(:set_monitor_association)
      provider.action_create
    end
  end

  describe '#action_delete' do
    it 'deletes the existing pool' do
      provider.current_resource.exists = true
      expect(locallb_pool).to receive(:delete_pool).with(['test_pool'])
      provider.action_delete
    end

    it 'does nothing when pool to delete do not exist' do
      provider.current_resource.exists = false
      expect(locallb_pool).not_to receive(:delete_pool)
      provider.action_delete
    end
  end
end

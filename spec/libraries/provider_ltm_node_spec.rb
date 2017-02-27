require 'spec_helper'

require 'chef/platform'
require 'chef/run_context'
require 'chef/resource'
require 'chef/event_dispatch/base'
require 'chef/event_dispatch/dispatcher'

require 'resource_ltm_node'

describe Chef::Provider::F5LtmNode do
  # Create a provider instance
  let(:provider) { Chef::Provider::F5LtmNode.new(new_resource, run_context) }

  # LoadBalancer stubbing
  let(:load_balancer) { double('F5::LoadBalancer', :client => client) }
  let(:client) do
    {
      'LocalLB.NodeAddressV2' => locallb_node_address_v2
    }
  end
  let(:locallb_node_address_v2) { double('LocalLB.NodeAddressV2') }

  # Some Chef stubbing
  let(:node) do
    node = Chef::Node.new
    node
  end
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }

  # Set current_resource and new_resource state
  let(:new_resource) do
    r = Chef::Resource::F5LtmNode.new('node1.test.com')
    r.f5('test')
    r
  end
  let(:current_resource) { Chef::Resource::F5LtmNode.new('node1.test.com') }

  # Tie some things together
  before do
    allow(provider).to receive(:load_current_resource).and_return(current_resource)
    allow(provider).to receive(:load_balancer).and_return(load_balancer)
    provider.new_resource = new_resource
    provider.current_resource = current_resource
  end

  describe '#action_create' do
    it 'creates a new node if not already created' do
      expect(locallb_node_address_v2).to receive(:create)
        .with([new_resource.node_name], [new_resource.node_name], [0])
      provider.action_create
    end

    it 'does nothing if node is already created' do
      provider.current_resource.exists = true
      expect(locallb_node_address_v2).not_to receive(:create)
      provider.action_create
    end

    it 'enables a disabled node' do
      provider.current_resource.exists = true
      provider.current_resource.enabled(false)
      expect(locallb_node_address_v2).to receive(:set_session_enabled_state)
        .with([new_resource.node_name], ['STATE_ENABLED'])
      provider.action_create
    end

    it 'does not enable an enabled node' do
      provider.current_resource.exists = true
      provider.current_resource.enabled(true)
      expect(locallb_node_address_v2).not_to receive(:set_session_enabled_state)
      provider.action_create
    end

    it 'disables an enabled node' do
      provider.new_resource.enabled(false)
      provider.current_resource.exists = true
      provider.current_resource.enabled(true)
      expect(locallb_node_address_v2).to receive(:set_session_enabled_state)
        .with([new_resource.node_name], ['STATE_DISABLED'])
      provider.action_create
    end

    it 'does not disable a disabled node' do
      provider.new_resource.enabled(false)
      provider.current_resource.exists = true
      provider.current_resource.enabled(false)
      expect(locallb_node_address_v2).not_to receive(:set_session_enabled_state)
      provider.action_create
    end
  end

  describe '#action_delete' do
    it 'deletes the existing node' do
      provider.current_resource.exists = true
      expect(locallb_node_address_v2).to receive(:delete_node_address)
        .with(['node1.test.com'])
      provider.action_delete
    end

    it 'does nothing when node to delete do not exist' do
      provider.current_resource.exists = false
      expect(locallb_node_address_v2).not_to receive(:delete_node_address)
      provider.action_delete
    end
  end
end

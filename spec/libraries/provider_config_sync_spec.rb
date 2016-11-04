require 'spec_helper'

require 'chef/platform'
require 'chef/run_context'
require 'chef/resource'
require 'chef/event_dispatch/base'
require 'chef/event_dispatch/dispatcher'

require 'resource_config_sync'

describe Chef::Provider::F5ConfigSync do
  # Create a provider instance
  let(:provider) { Chef::Provider::F5ConfigSync.new(new_resource, run_context) }

  # LoadBalancer stubbing
  let(:load_balancer) do
    double('F5::LoadBalancer', :client => client, :active? => true,
                               :system_hostname => 'test.test.com',
                               :device_groups => %w(dev prod))
  end
  let(:client) { { 'System.ConfigSync' => locallb_config_sync } }
  let(:locallb_config_sync) { double('System.ConfigSync') }

  # Some Chef stubbing
  let(:node) { Chef::Node.new }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }

  # Set current_resource and new_resource state
  let(:new_resource) do
    r = Chef::Resource::F5ConfigSync.new('test.test.com')
    r.f5('test.test.com')
    r
  end
  let(:current_resource) { Chef::Resource::F5ConfigSync.new('test.test.com') }

  # Tie some things together
  before do
    allow(provider).to receive(:load_current_resource).and_return(current_resource)
    allow(provider).to receive(:load_balancer).and_return(load_balancer)
    provider.new_resource = new_resource
    provider.current_resource = current_resource
  end

  describe '#action_run' do
    describe 'active f5' do
      it 'pushes configs to other devices' do
        expect(locallb_config_sync).to receive(:synchronize_to_group_v2).with('dev', 'test.test.com', true)
        expect(locallb_config_sync).to receive(:synchronize_to_group_v2).with('prod', 'test.test.com', true)
        provider.action_run
      end

      it 'does not push configs if no device groups' do
        allow(load_balancer).to receive(:device_groups).and_return([])
        expect(locallb_config_sync).not_to receive(:synchronize_to_group_v2)
        provider.action_run
      end
    end

    describe 'standby f5' do
      before do
        allow(load_balancer).to receive(:active?).and_return(false)
      end

      it 'does not push configs' do
        expect(locallb_config_sync).not_to receive(:synchronize_to_group_v2)
        provider.action_run
      end
    end
  end
end

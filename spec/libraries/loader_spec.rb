require 'spec_helper'

module F5
  describe Loader do
    include F5::Loader

    # Create a provider instance
    let(:provider) { Chef::Provider::F5LtmMonitor.new(new_resource, run_context) }

    # LoadBalancer stubbing
    let(:load_balancer) { double('F5::LoadBalancer') }
    let(:load_balancer_exists) { double('F5::LoadBalancer', :name => 'test.test.com') }

    # Some Chef stubbing
    let(:node) do
      node = Chef::Node.new
      node.set['f5-bigip']['credentials']['databag'] = 'f5'
      node.set['f5-bigip']['credentials']['item'] = 'creds'
      node.set['f5-bigip']['credentials']['key'] = ''
      node.set['f5-bigip']['credentials']['host_is_key'] = false
      node
    end
    let(:events) { Chef::EventDispatch::Dispatcher.new }
    let(:run_context) { Chef::RunContext.new(node, {}, events) }
    let(:creds) { { 'username' => 'test_user', 'password' => 'test_pass' } }

    # Set current_resource and new_resource state
    let(:new_resource) do
      r = Chef::Resource::F5LtmMonitor.new('/Common/test_monitor')
      r.f5('test.test.com')
      r
    end

    let(:wanted_interfaces) do
      [
        'Management.Partition',
        'LocalLB.Monitor',
        'LocalLB.NodeAddressV2',
        'LocalLB.Pool',
        'LocalLB.VirtualServer',
        'Management.DeviceGroup',
        'System.ConfigSync',
        'System.Failover',
        'System.Inet'
      ]
    end

    before do
      allow_any_instance_of(F5::Loader).to receive(:chef_vault_item).and_return(creds)
      F5::Loader.class_variable_set :@@load_balancers, nil
    end

    describe '#convert_to_array' do
      it 'returns the original Array' do
        expect(convert_to_array([123, 345])).to eq([123, 345])
      end

      it 'returns single element Array of object' do
        expect(convert_to_array('test')).to eq(['test'])
      end
    end

    describe '#interfaces' do
      it 'returns list of F5 icontrol interfaces to load' do
        expect(interfaces).to eq(wanted_interfaces)
      end
    end

    describe '#load_balancer' do
      it 'returns matching load balancer' do
        # Create it
        allow(provider).to receive(:create_icontrol).and_return(load_balancer)
        provider.load_balancer

        # Test that we do not create again
        expect(provider).not_to receive(:create_icontrol)
        provider.load_balancer
        expect(provider.load_balancer).to be_a(F5::LoadBalancer)
        expect(provider.load_balancer.name).to eq('test.test.com')
      end

      it 'creates and returns missing load balancer' do
        expect(provider).to receive(:create_icontrol).and_return(load_balancer)
        provider.load_balancer
        expect(provider.load_balancer).to be_a(F5::LoadBalancer)
        expect(provider.load_balancer.name).to eq('test.test.com')
      end
    end

    describe '#create_icontrol' do
      let(:icontrol) { double('F5::IControl', :get_interfaces => true) }
      it 'creates a new f5 icontrol interface' do
        expect(F5::IControl).to receive(:new)
          .with('test.test.com', 'test_user', 'test_pass', wanted_interfaces)
          .and_return(icontrol)
        expect(icontrol).to receive(:get_interfaces)
        provider.create_icontrol('test.test.com')
        # expect(provider.load_balancer).to be_a(F5::LoadBalancer)
        # expect(provider.load_balancer.name).to eq('test.test.com')
      end
    end
  end
end

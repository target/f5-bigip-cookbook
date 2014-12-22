require 'spec_helper'

# rubocop:disable Documentation
module F5
  describe LoadBalancer::Ltm do
    let(:client) { double('F5::IControl') }
    let(:nodes) do
      [
        { 'name' => 'node-test1', 'address' => '10.10.10.10', 'enabled' => true },
        { 'name' => 'node-test2', 'address' => '10.10.10.11', 'enabled' => false }
      ]
    end
    let(:monitors) { instance_double('F5::LoadBalancer::Ltm::Monitors') }
    let(:pools) { instance_double('F5::LoadBalancer::Ltm::Pools') }
    let(:virtual_servers) { instance_double('F5::LoadBalancer::Ltm::VirtualServers') }
    let(:local_lb_node_address) do
      double 'LocalLB.NodeAddressV2', :get_list => %w(node-test1 node-test2),
                                      :get_address => ['10.10.10.10', '10.10.10.11'],
                                      :get_object_status => [{ 'enabled_status' => 'ENABLED_STATUS_ENABLED' }, { 'enabled_status' => 'ENABLED_STATUS_DISABLED' }]
    end
    # let(:management_device_group) do
    #   double 'Management.DeviceGroup', :get_list => ['/Common/test1', '/Common/device_trust_group',
    #                                                  '/Common/test2', '/Common/gtm', '/Common/test3']
    # end
    # let(:system_failover) do
    #   double 'System.Failover', :get_failover_state => 'FAILOVER_STATE_ACTIVE'
    # end
    # let(:system_inet) do
    #   double 'System.Inet', :get_hostname => 'test-f5.test.com'
    # end

    let(:ltm) { F5::LoadBalancer::Ltm.new(client) }

    before do
      allow(client).to receive(:[]).with('LocalLB.NodeAddressV2')
                                        .and_return(local_lb_node_address)
      # allow(client).to receive(:[]).with('Management.DeviceGroup')
      #                                   .and_return(management_device_group)
      # allow(client).to receive(:[]).with('System.Failover')
      #                                   .and_return(system_failover)
      # allow(client).to receive(:[]).with('System.Inet')
      #                                   .and_return(system_inet)
    end

    describe '#nodes' do
      it 'returns @nodes' do
        ltm.instance_variable_set(:@nodes, nodes)
        expect(client).to_not receive(:[]).with('LocalLB.NodeAddressV2')
        expect(ltm.nodes).to eq(nodes)
      end

      it 'sets @nodes if not already set and then returns it' do
        expect(ltm.nodes).to eq(nodes)
      end
    end

    describe '#monitors' do
      it 'returns @monitors' do
        ltm.instance_variable_set(:@monitors, monitors)
        expect(F5::LoadBalancer::Ltm::Monitors).not_to receive(:new)
        expect(ltm.monitors).to eq(monitors)
      end

      it 'sets @monitors if not already set and then returns it' do
        expect(F5::LoadBalancer::Ltm::Monitors).to receive(:new).and_return(monitors)
        expect(ltm.monitors).to eq(monitors)
      end
    end

    describe '#pools' do
      it 'returns @pools' do
        ltm.instance_variable_set(:@pools, pools)
        expect(F5::LoadBalancer::Ltm::Pools).not_to receive(:new)
        expect(ltm.pools).to eq(pools)
      end

      it 'sets @pools if not already set and then returns it' do
        expect(F5::LoadBalancer::Ltm::Pools).to receive(:new).and_return(pools)
        expect(ltm.pools).to eq(pools)
      end
    end

    describe '#virtual_servers' do
      it 'returns @virtual_servers' do
        ltm.instance_variable_set(:@virtual_servers, virtual_servers)
        expect(F5::LoadBalancer::Ltm::VirtualServers).not_to receive(:new)
        expect(ltm.virtual_servers).to eq(virtual_servers)
      end

      it 'sets @virtual_servers if not already set and then returns it' do
        expect(F5::LoadBalancer::Ltm::VirtualServers).to receive(:new).and_return(virtual_servers)
        expect(ltm.virtual_servers).to eq(virtual_servers)
      end
    end
  end
end

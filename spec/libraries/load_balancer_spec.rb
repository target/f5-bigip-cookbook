require 'spec_helper'

module F5
  describe LoadBalancer do
    let(:client) { double('F5::IControl') }
    let(:management_device_group) do
      double 'Management.DeviceGroup', :get_list => ['/Common/test1', '/Common/device_trust_group',
                                                     '/Common/test2', '/Common/gtm', '/Common/test3']
    end
    let(:system_failover) do
      double 'System.Failover', :get_failover_state => 'FAILOVER_STATE_ACTIVE'
    end
    let(:system_inet) do
      double 'System.Inet', :get_hostname => 'test-f5.test.com'
    end
    let(:management_partition) do
      double 'Management.Partition', :get_active_partition => 'Common'
    end

    let(:load_balancer) { F5::LoadBalancer.new('test-f5', client) }

    before do
      allow(client).to receive(:[]).with('Management.DeviceGroup').and_return(management_device_group)
      allow(client).to receive(:[]).with('System.Failover').and_return(system_failover)
      allow(client).to receive(:[]).with('System.Inet').and_return(system_inet)
      allow(client).to receive(:[]).with('Management.Partition').and_return(management_partition)
    end

    describe '#ltm' do
      it 'returns @ltm' do
        load_balancer.instance_variable_set(:@ltm, 'test')
        expect(F5::LoadBalancer::Ltm).to_not receive(:new)
        expect(load_balancer.ltm).to eq('test')
        expect(load_balancer.active_partition).to eq('Common')
      end

      it 'sets @ltm if not already set and then returns it' do
        expect(load_balancer.ltm).to be_a(F5::LoadBalancer::Ltm)
      end
    end

    describe '#change_partition' do
      it 'changes the active partition' do
        expect(load_balancer.change_partition).to eq(true)
      end
    end

    describe '#system_hostname' do
      it 'returns hostname the device has in the config' do
        expect(load_balancer.system_hostname).to eq('test-f5.test.com')
      end
    end

    describe '#active?' do
      it 'returns true when FAILOVER_STATE_ACTIVE' do
        expect(load_balancer.active?).to eq(true)
      end

      it 'returns false when not FAILOVER_STATE_ACTIVE' do
        allow(system_failover).to receive(:get_failover_state).and_return('FAILOVER_STATE_INACTIVE')
        expect(load_balancer.active?).to eq(false)
      end
    end

    describe '#device_groups' do
      it 'returns a list of device groups' do
        expect(load_balancer.device_groups).to eq(['/Common/test1', '/Common/test2', '/Common/test3'])
      end
    end
  end
end

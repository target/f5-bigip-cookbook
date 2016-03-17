require 'spec_helper'

describe F5::LoadBalancer::Ltm::VirtualServers::VirtualServer do
  let(:virtual_server) { F5::LoadBalancer::Ltm::VirtualServers::VirtualServer.new('/Common/test') }

  describe '.new' do
    it 'creates a new F5::LoadBalancer::Ltm::VirtualServers::VirtualServer' do
      expect(virtual_server).to be_a(F5::LoadBalancer::Ltm::VirtualServers::VirtualServer)
      expect(virtual_server.name).to eq('/Common/test')
    end
  end

  describe '#enabled' do
    it 'returns false' do
      virtual_server.status = { 'enabled_status' => 'ENABLED_STATUS_DISABLED' }
      expect(virtual_server.enabled).to eq(false)
    end

    it 'returns true' do
      virtual_server.status = { 'enabled_status' => 'ENABLED_STATUS_ENABLED' }
      expect(virtual_server.enabled).to eq(true)
    end
  end
end

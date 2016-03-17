require 'spec_helper'

describe F5::LoadBalancer::Ltm::Monitors::Monitor do
  let(:monitor_hash) do
    { 'template_name' => '/Common/test', 'template_type' => 'TTYPE_HTTPS' }
  end
  let(:monitor) { F5::LoadBalancer::Ltm::Monitors::Monitor.new(monitor_hash) }

  describe '.new' do
    it 'creates a new F5::LoadBalancer::Ltm::Monitors::Monitor' do
      expect(F5::LoadBalancer::Ltm::Monitors::Monitor.new(monitor_hash)).to be_a(F5::LoadBalancer::Ltm::Monitors::Monitor)
      expect(F5::LoadBalancer::Ltm::Monitors::Monitor.new(monitor_hash).name).to eq('/Common/test')
      expect(F5::LoadBalancer::Ltm::Monitors::Monitor.new(monitor_hash).type).to eq('TTYPE_HTTPS')
    end
  end
end

require 'spec_helper'

describe F5::LoadBalancer::Ltm::VirtualServers do
  let(:client) { double('F5::IControl') }
  let(:locallb_vs) do
    double 'LocalLB.LtmVirtualServer', :get_list => vs_names,
                                       :get_wildmask => wildmasks,
                                       :get_destination_v2 => destinations,
                                       :get_type => types,
                                       :get_default_pool_name => default_pools,
                                       :get_protocol => protocols,
                                       :get_profile => profiles,
                                       :get_object_status => statuses,
                                       :get_vlan => vlans,
                                       :get_source_address_translation_type => snat_types,
                                       :get_source_address_translation_snat_pool => snat_pools,
                                       :get_persistence_profile => default_persistence_profiles,
                                       :get_fallback_persistence_profile => fallback_persistence_profiles,
                                       :get_rule => rules
  end
  let(:vs_names) do
    ['/Common/vs_test1', '/Common/vs_test2']
  end
  let(:wildmasks) do
    ['255.255.255.255', '255.255.255.255']
  end
  let(:destinations) do
    [
      { 'address' => '10.10.10.10', 'port' => 80 },
      { 'address' => '10.10.10.11', 'port' => 443 }
    ]
  end
  let(:types) do
    %w(RESOURCE_TYPE_POOL RESOURCE_TYPE_POOL)
  end
  let(:default_pools) do
    ['/Common/vs_default1', '/Common/vs_default2']
  end
  let(:protocols) do
    %w(PROTOCOL_TCP PROTOCOL_TCP)
  end
  let(:profiles) do
    [
      ['profile_type' => 'PROFILE_TYPE_TCP', 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp'],
      ['profile_type' => 'PROFILE_TYPE_TCP', 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp']
    ]
  end
  let(:statuses) do
    [
      'availability_status' => 'AVAILABILITY_STATUS_RED', 'enabled_status' => 'ENABLED_STATUS_DISABLED', 'status_description' => 'The children pool member(s) are down',
      'availability_status' => 'AVAILABILITY_STATUS_RED', 'enabled_status' => 'ENABLED_STATUS_ENABLED', 'status_description' => 'The children pool member(s) are down'
    ]
  end
  let(:vlans) do
    [
      'state' => 'STATE_DISABLED', 'vlans' => [],
      'state' => 'STATE_ENABLED', 'vlans' => ['/Common/vagrant_int']
    ]
  end
  let(:snat_types) do
    %w(SRC_TRANS_SNATPOOL SRC_TRANS_AUTOMAP)
  end
  let(:snat_pools) do
    ['/Common/test_snat_pool', nil]
  end
  let(:default_persistence_profiles) do
    [
      [{ 'profile_name' => '/Common/cookie', 'default_profile' => true }],
      [{ 'profile_name' => '/Common/ssl', 'default_profile' => false }]
    ]
  end
  let(:fallback_persistence_profiles) do
    ['/Common/hash', nil]
  end
  let(:rules) do
    [
      [
        { 'rule_name' => '/Common/test_rule1', 'priority' => 2 },
        { 'rule_name' => '/Common/test_rule2', 'priority' => 1 }
      ],
      []
    ]
  end
  let(:exp_rules) do
    [
      [
        '/Common/test_rule2',
        '/Common/test_rule1'
      ],
      []
    ]
  end
  let(:virtual_servers) { F5::LoadBalancer::Ltm::VirtualServers.new(client) }

  before do
    allow(client).to receive(:[]).with('LocalLB.VirtualServer').and_return(locallb_vs)
  end

  describe '#all' do
    it 'is an Array of F5::LoadBalancer::Ltm::VirtualServers::VirtualServer' do
      expect(virtual_servers.all).to be_an(Array)
      expect(virtual_servers.all).not_to be_empty

      virtual_servers.all.each do |v|
        expect(v).to be_a(F5::LoadBalancer::Ltm::VirtualServers::VirtualServer)
      end
    end

    it 'is empty when no virtual servers are returned from f5' do
      allow(locallb_vs).to receive(:get_list).and_return([])
      expect(virtual_servers.all).to be_empty
    end
  end

  describe '#names' do
    it 'returns an array of the names of the virtual servers' do
      expect(virtual_servers.names).to be_an(Array)
      expect(virtual_servers.names).to eq(vs_names)
    end
  end

  describe '#refresh_destination_wildmask' do
    it 'gathers the wildmask for the virtual server' do
      expect(locallb_vs).to receive(:get_wildmask).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:destination_wildmask=).with(wildmasks[idx])
      end
      virtual_servers.refresh_destination_wildmask
    end
  end

  describe '#refresh_destination_address' do
    it 'gathers the destination address for the virtual server' do
      expect(locallb_vs).to receive(:get_destination_v2).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:destination_address=).with(destinations[idx]['address'])
        expect(vs).to receive(:destination_port=).with(destinations[idx]['port'])
      end
      virtual_servers.refresh_destination_address
    end
  end

  describe '#refresh_type' do
    it 'gathers the type for the virtual server' do
      expect(locallb_vs).to receive(:get_type).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:type=).with(types[idx])
      end
      virtual_servers.refresh_type
    end
  end

  describe '#refresh_default_pool' do
    it 'gathers the default pool for the virtual server' do
      expect(locallb_vs).to receive(:get_default_pool_name).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:default_pool=).with(default_pools[idx])
      end
      virtual_servers.refresh_default_pool
    end
  end

  describe '#refresh_status' do
    it 'gathers the status for the virtual server' do
      expect(locallb_vs).to receive(:get_object_status).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:status=).with(statuses[idx])
      end
      virtual_servers.refresh_status
    end
  end

  describe '#refresh_protocol' do
    it 'gathers the protocol for the virtual server' do
      expect(locallb_vs).to receive(:get_protocol).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:protocol=).with(protocols[idx])
      end
      virtual_servers.refresh_protocol
    end
  end

  describe '#refresh_profiles' do
    it 'gathers the profiles for the virtual server' do
      expect(locallb_vs).to receive(:get_profile).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:profiles=).with(profiles[idx])
      end
      virtual_servers.refresh_profiles
    end
  end

  describe '#refresh_vlans' do
    it 'gathers the vlans for the virtual server' do
      expect(locallb_vs).to receive(:get_vlan).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:vlans=).with(vlans[idx])
      end
      virtual_servers.refresh_vlans
    end
  end

  describe '#refresh_snat' do
    it 'gathers the snat type for the virtual server' do
      expect(locallb_vs).to receive(:get_source_address_translation_type).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:snat_type=).with(snat_types[idx])
      end
      virtual_servers.refresh_snat
    end

    it 'gathers the snat pool for the virtual server' do
      expect(locallb_vs).to receive(:get_source_address_translation_snat_pool).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs).to receive(:snat_pool=).with(snat_pools[idx])
      end
      virtual_servers.refresh_snat
    end
  end

  describe '#refresh_rules' do
    it 'gathers the iRules virtual server' do
      expect(locallb_vs).to receive(:get_rule).with(vs_names)
      virtual_servers.all.each_with_index do |vs, idx|
        expect(vs.rules).to eq(exp_rules[idx])
      end
      virtual_servers.refresh_persistence
    end
  end
end

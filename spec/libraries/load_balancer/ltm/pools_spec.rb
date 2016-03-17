require 'spec_helper'

describe F5::LoadBalancer::Ltm::Pools do
  let(:pools) { F5::LoadBalancer::Ltm::Pools.new(client) }

  let(:client) { double('F5::IControl') }
  let(:locallb_pool) do
    double 'LocalLB.Pool', :get_list => pool_names,
                           :get_member_v2 => members,
                           :get_member_object_status => members_statuses,
                           :get_monitor_association => monitors,
                           :get_lb_method => lb_methods
  end
  let(:pool_names) do
    ['/Common/pool_test1', '/Common/pool_test2']
  end
  let(:members) do
    [
      [
        {
          'address' => '10.10.10.10',
          'port' => '80'
        },
        {
          'address' => '10.10.10.11',
          'port' => '80'
        }
      ],
      [
        {
          'address' => '10.10.10.10',
          'port' => '443'
        },
        {
          'address' => '10.10.10.10',
          'port' => '444'
        }
      ]
    ]
  end
  let(:members_statuses) do
    [
      [
        'availability_status' => 'AVAILABILITY_STATUS_RED', 'enabled_status' => 'ENABLED_STATUS_DISABLED', 'status_description' => 'The pool is down',
        'availability_status' => 'AVAILABILITY_STATUS_RED', 'enabled_status' => 'ENABLED_STATUS_ENABLED', 'status_description' => 'The pool is down'
      ],
      [
        'availability_status' => 'AVAILABILITY_STATUS_RED', 'enabled_status' => 'ENABLED_STATUS_ENABLED', 'status_description' => 'The pool is down',
        'availability_status' => 'AVAILABILITY_STATUS_RED', 'enabled_status' => 'ENABLED_STATUS_DISABLED', 'status_description' => 'The pool is down'

      ]
    ]
  end
  let(:monitors) do
    [
      {
        'pool_name' => '/Common/pool_test1',
        'monitor_rule' => {
          'type' => 'MONITOR_RULE_TYPE_AND_LIST',
          'quorum' => 2,
          'monitor_templates' => ['/Common/tcp', '/Common/https']
        }
      },
      {
        'pool_name' => '/Common/pool_test2',
        'monitor_rule' => {
          'type' => 'MONITOR_RULE_TYPE_SINGLE',
          'quorum' => 2,
          'monitor_templates' => ['/Common/https']
        }
      }
    ]
  end
  let(:lb_methods) do
    %w(LB_METHOD_RATIO_MEMBER LB_METHOD_ROUND_ROBIN)
  end

  before do
    allow(client).to receive(:[]).with('LocalLB.Pool').and_return(locallb_pool)
  end

  describe '#pool_names' do
    it 'is an Array of pool names' do
      expect(pools.pool_names).to be_an(Array)
      expect(pools.pool_names).not_to be_empty
    end

    it 'is empty when no pools are returned from f5' do
      allow(locallb_pool).to receive(:get_list).and_return([])
      expect(pools.pool_names).to be_empty
    end
  end

  describe '#refresh_members' do
    it 'retrieves members of pools' do
      expect(locallb_pool).to receive(:get_member_v2).with(pool_names)
      pools.refresh_members
    end

    it 'returns no pool members' do
      expect(locallb_pool).to receive(:get_member_v2)
        .with(pool_names)
        .and_return([[], []])
      pool_names.each_with_index do |_p, pi|
        expect(pools.all[pi].members).to be_empty
      end
      pools.refresh_members
    end

    it 'assigns members to pools' do
      members.each_with_index do |m, pi|
        m.each_with_index do |member, mi|
          expect(pools.all[pi].members[mi].address).to eq(member['address'])
          expect(pools.all[pi].members[mi].port).to eq(member['port'])
        end
      end
      pools.refresh_members
    end
  end

  describe '#refresh_lb_method' do
    it 'retrieves load balancing method' do
      expect(locallb_pool).to receive(:get_lb_method).with(pool_names)
      pools.refresh_lb_method
    end

    it 'assigns load balancing method' do
      lb_methods.each_with_index do |lb, li|
        expect(pools.all[li].lb_method).to eq(lb)
      end
      pools.refresh_members
    end
  end

  describe '#refresh_monitors' do
    it 'retrieves monitors' do
      expect(locallb_pool).to receive(:get_monitor_association).with(pool_names)
      pools.refresh_monitors
    end

    it 'assigns monitors' do
      monitors.each_with_index do |m, pi|
        expect(pools.all[pi].monitors).to eq(m['monitor_rule'])
      end
      pools.refresh_monitors
    end
  end
end

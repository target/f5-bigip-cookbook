require 'spec_helper'

describe 'f5-bigip::provision_delete' do
  cached(:chef_run) do
    ChefSpec::ServerRunner.new do |_node, server|
      server.create_data_bag('f5-provisioner',
                             f5_provisioner_databag_data)
    end.converge(described_recipe)
  end

  let(:f5_provisioner_databag_data) do
    {
      'f5-one' => {
        'hostname' => 'f5-one',
        'delete' => {
          'virtual_servers' => %w(del_one del_two),
          'pools' => %w(del_one del_two),
          'monitors' => %w(del_one del_two),
          'nodes' => %w(del_one del_two)
        }
      }
    }
  end

  it 'deletes virtual servers' do
    expect(chef_run).to delete_f5_ltm_virtual_server('f5-one-del_one')
    expect(chef_run).to delete_f5_ltm_virtual_server('f5-one-del_two')
  end

  it 'deletes pools' do
    expect(chef_run).to delete_f5_ltm_pool('f5-one-del_one')
    expect(chef_run).to delete_f5_ltm_pool('f5-one-del_two')
  end

  it 'deletes monitors' do
    expect(chef_run).to delete_f5_ltm_monitor('f5-one-del_one')
    expect(chef_run).to delete_f5_ltm_monitor('f5-one-del_two')
  end

  it 'deletes nodes' do
    expect(chef_run).to delete_f5_ltm_node('f5-one-del_one')
    expect(chef_run).to delete_f5_ltm_node('f5-one-del_two')
  end
end

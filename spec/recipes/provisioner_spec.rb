require 'spec_helper'

describe 'f5-bigip::provisioner' do
  let(:chef_server) do
    ChefSpec::ServerRunner.new do |_node, server|
      server.create_data_bag('f5-provisioner',
                             f5_provisioner_databag_data)
    end
  end
  let(:chef_run) { chef_server.converge(described_recipe) }

  let(:f5_provisioner_databag_data) do
    {}
  end

  it 'includes provision recipes' do
    expect(chef_run).to include_recipe('f5-bigip::provision_delete')
    expect(chef_run).to include_recipe('f5-bigip::provision_create')
  end
end

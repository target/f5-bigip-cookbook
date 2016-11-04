require 'spec_helper'

describe 'f5-bigip::provision_configsync' do
  let(:chef_server) do
    ChefSpec::ServerRunner.new do |_node, server|
      server.create_data_bag('f5-provisioner',
                             f5_provisioner_databag_data)
    end
  end
  let(:chef_run) { chef_server.converge(described_recipe) }

  let(:f5_provisioner_databag_data) do
    {
      'f5-one' => {
        'hostname' => 'f5-one',
        'create' => {
          'monitors' => {
            'one' => {
              'parent' => nil
            },
            'two' => {
              'parent' => '/Common/https'
            }
          }
        }
      },
      'f5-two' => {
        'hostname' => 'f5-two'
      }
    }
  end

  it 'creates config sync resources that do nothing for each f5 device' do
    config_sync_f5_one = chef_run.f5_config_sync('f5-one')
    config_sync_f5_two = chef_run.f5_config_sync('f5-two')
    expect(config_sync_f5_one).to do_nothing
    expect(config_sync_f5_two).to do_nothing
  end
end

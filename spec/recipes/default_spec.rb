require 'spec_helper'

describe 'f5-bigip::default' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  it 'installs gem soap4r-spox' do
    expect(chef_run).to install_chef_gem('soap4r-spox').with('version' => '1.6.0')
  end

  it 'creates cache of f5-icontrol gem' do
    expect(chef_run).to create_cookbook_file("#{Chef::Config[:file_cache_path]}/f5-icontrol.gem").at_compile_time
  end

  it 'installs gem f5-icontrol' do
    expect(chef_run).to install_chef_gem('f5-icontrol').with('version' => '11.4.1.0')
  end
end

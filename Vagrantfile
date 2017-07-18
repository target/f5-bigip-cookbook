# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

$if_script = <<SCRIPT
if [[ ! -f /etc/sysconfig/network-scripts/ifcfg-eth1 ]]; then
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<EOF
DEVICE="eth1"
BOOTPROTO="static"
IPADDR='192.168.10.10'
NETMASK='255.255.255.0'

IPV6INIT="no"
MTU="1500"
ONBOOT="yes"
TYPE="Ethernet"
EOF

ifup eth1
fi
SCRIPT

Vagrant.configure('2') do |config|
  config.vm.define 'f5' do |f5|
    # Every Vagrant virtual environment requires a box to build off of
    f5.vm.box = 'f5-ltm-ve'
  end

  config.vm.define 'admin' do |admin|
    # Set hostname
    admin.vm.hostname = 'f5-admin'

    # Every Vagrant virtual environment requires a box to build off of
    admin.vm.box = 'chef/centos-6.5'

    # The url from where the 'config.vm.box' box will be fetched if it
    # doesn't already exist on the user's system
    admin.vm.box_url = 'chef/centos-6.5'

    admin.vm.provider :virtualbox do |vb|
      # Change network type of interface to match load balancer
      vb.customize ['modifyvm', :id, '--nic2', 'intnet']
    end

    # Install Chef
    admin.omnibus.chef_version = :latest
    admin.omnibus.install_url = 'http://www.opscode.com/chef/install.sh'

    # Enabling the Berkshelf plugin
    admin.berkshelf.enabled = true

    # Set IP on admin node
    admin.vm.provision 'shell', inline: $if_script

    # Chef run to create things
    admin.vm.provision :chef_solo do |chef|
      chef.data_bags_path = 'test/integration/data_bags'

      chef.json = {
        'f5-bigip' => {
          'provisioner' => {
            'databag' => 'f5-provisioner-1',
          },
        },
        'minitest' => {
          'recipes' => ['f5-bigip::create'],
        },
        'dev_mode' => true,
      }

      chef.add_recipe 'minitest-handler::default'
      chef.add_recipe 'f5-bigip::default'
      chef.add_recipe 'f5-bigip::provisioner'
    end

    # Set run_list and attributes for chef
    admin.vm.provision :chef_solo do |chef|
      chef.data_bags_path = 'test/integration/data_bags'

      chef.json = {
        'f5-bigip' => {
          'provisioner' => {
            'databag' => 'f5-provisioner-2',
          },
        },
        'dev_mode' => true,
      }

      chef.add_recipe 'minitest-handler::default'
      chef.add_recipe 'f5-bigip::provisioner'
    end
  end
end

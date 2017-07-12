name             'f5-bigip'
maintainer       'Target'
maintainer_email 'jacob.mccann2@target.com'
license          'Apache 2.0'
description      'Installs/Configures f5-icontrol'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
source_url       'https://github.com/target/f5-bigip-cookbook'
issues_url       'https://github.com/target/f5-bigip-cookbook/issues'
chef_version     '>= 12.1' if respond_to?(:chef_version)
supports         'all'
version          '0.5.2'

depends 'chef-vault'

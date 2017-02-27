# This version is a fork of
# https://github.com/target/f5-bigip-cookbook/
# and it's not maintained by Target.
#
# With my compliments to Target and Jacob, this version supports iRules and Partitions whilst the original
# version does not and probably never will.
#
name             'f5-bigip'
maintainer       'Sergio Rua'
maintainer_email 'github@rua.me.uk'
license          'Apache 2.0'
description      'Installs/Configures f5-icontrol'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
source_url       'https://github.com/target/f5-bigip-cookbook'
issues_url       'https://github.com/target/f5-bigip-cookbook/issues'
version          '0.5.7'

depends 'chef-vault'

f5-bigip cookbook
=================
[![Build Status](https://travis-ci.org/target/f5-bigip-cookbook.svg)](https://travis-ci.org/target/f5-bigip-cookbook)

Control F5 load balancer config

Requirements
============

An F5 to manage

Usage
=====

You assign this to a node to manage an F5 devices

Attributes
==========

* `node['f5-bigip']['credentials']['databag']` - Databag with credentials
* `node['f5-bigip']['credentials']['item']` - Databag Item with credentials
* `node['f5-bigip']['credentials']['key']` - Key in Databag Item with credentials
* `node['f5-bigip']['credentials']['host_is_key']` - Set to true to grab specific credentials for each f5 host based on f5 hostname being used as a key in the specified databag::item
* `node['f5-bigip']['provisioner']['databag']` - Databag that contains an item for each f5 you want to manage with `f5::provisioner`.  Check test/integration/data_bags/f5-provisioner-* for sample data bag structures.

Definitions
===========

f5_vip
------
This definition is a wrapper for the [`f5_ltm_node`](#f5_ltm_node), [`f5_ltm_pool`](#f5_ltm_pool) and [`f5_ltm_virtual_server`](#f5_ltm_virtual_server) LWPRs.  It allows you to specify all the required info into the `f5_vip` definition which will then be translated into the necessary LWRP declarations.

### Parameters

|    Attr   |   Default/Req?    |    Type    |       Description        |
|-----------|-------------------|------------|--------------------------|
| f5        | **REQUIRED**    | String     | f5 to create the node on |
| nodes | **REQUIRED** | Array[String] | Nodes (ip addresses) to load balance the VIP against |
| pool | **REQUIRED** | String | Name to create node with |
| lb_method | `LB_METHOD_ROUND_ROBIN` | String | Load balancing method |
| monitors | [] | Array[String] | Monitors to check that nodes are available |
| virtual_server | resource's name | String | Name of virtual server to create on f5 |
| destination_address | **REQUIRED** | String | Destination IP Address |
| destination_port | 443 | Integer | Destination Port |
| vlan_state | 'STATE_DISABLED' | String | Wether list of VLANs are disabled or enabled |
| vlans | [] | Array[String] | List of VLANs to enabled or disable based on `vlan_state` |
| profiles | [{<br/>'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',<br/>'profile_name' => '/Common/tcp'<br/>}] | Array[Hash] | Profiles to associate to virtual server |
| snat_type | 'SRC_TRANS_NONE' | String | Snat type to set on virtual server |
| snat_pool | '' | String | Snat pool to use if `snat_type` set to 'SRC_TRANS_SNATPOOL', otherwise ignored |
| default_persistence_profile | '' | String | Default persistence profile to associate with virtual server |
| fallback_persistence_profile | '' | String | Fallback persistence profile to associate with virtual server |
| rules | [] | Array[String] | iRules to associate with virtual server |
| partition | '' | String | Partition name where to create this VIP. It must exist. |
| description | '' | String | VS description |
| translate_port | '' | Boolean | Enable/Disable port translation |
| translate_address | '' | Boolean | Enable/Disable address translation |

### Example
The simplest VIP declartion that takes as many defaults as possible:
```ruby
f5_vip 'testing.test.com' do
  f5 'test-f5.test.com'
  nodes ['10.10.10.10', '10.10.10.11']
  pool 'test-pool'
  destination_address '192.168.1.10'
end
```

It will create
* Two nodes, named after their ip addresses
* A pool referencing the nodes as members with no monitors
* A virtual server listening on `<destination_address>:443`

A fully user defined VIP:
```ruby
f5_vip 'testing.test.com' do
  f5 'test-f5.test.com'
  nodes ['10.10.10.10', '10.10.10.11']
  member_port 4443
  pool 'test-pool'
  lb_method 'LB_METHOD_RATIO_MEMBER'
  monitors ['/Common/https', '/Common/tcp']
  destination_address '192.168.1.10'
  destination_port 8443
  profiles [
    { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/tcp' },
    { 'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL', 'profile_name' => '/Common/http' }
  ]
  vlan_state 'STATE_ENABLED'
  vlans ['/Common/vlan123', '/Common/vlan234']
  snat_type 'SRC_TRANS_SNATPOOL'
  snat_pool '/Common/snat_pool'
  default_persistence_profile '/Common/test_persistence_profile'
  fallback_persistence_profile '/Common/test2_persistence_profile'
  rules ['/Common/_sys_auth_ldap', '/Common/_sys_auth_radius']
end
```

LWRPs
=====

These LWRPs allow you to idempotently manage various F5 resources.  This is accomplished by using a 'proxy' node that manages the F5 through the use of the [F5's APIs](https://devcentral.f5.com/wiki/iControl.LocalLB.ashx).

f5_ltm_node
-----------
`f5_ltm_node` - Used to manage [nodes](https://devcentral.f5.com/wiki/iControl.LocalLB__NodeAddressV2.ashx).

### Attributes

|    Attr   |   Default/Req?    |    Type    |       Description              |
|-----------|-------------------|------------|--------------------------------|
| node_name | The resource name | String     | Name to create node with       |
| address   | `node_name`       | String     | IP address to create node with |
| description   |        | String     | Node description |
| f5        | **REQUIRED**      | String     | f5 to create the node on       |
| enabled   | `true`            | true/false | State node should be in        |

If the `address` attribute is unset, the `node_name` (which in turn defaults to the resource's name) will be used instead.

`node_name` can be prefixed with a partition name, for example `/internal/node_name`. Default is `/Common`.

### Examples

The following creates a node with name and address of `10.10.10.10`:
```ruby
f5_ltm_node '10.10.10.10' do
  f5 'f5-test.test.com'
  enabled true
end
```

The following creates a node named `test-node.test.com` with `10.10.10.10` as the ip address:
```ruby
f5_ltm_node 'test-node.test.com' do
  address '10.10.10.10'
  f5 'f5-test.test.com'
  enabled true
end
```

f5_ltm_pool
-----------
`f5_ltm_pool` - Used to manage [pools](https://devcentral.f5.com/wiki/iControl.LocalLB__Pool.ashx)

### Attributes

| Attr | Default/Req? | Type | Description |
|------|--------------|------|-------------|
| pool_name | The resource name | String | Name to create node with |
| f5 | **REQUIRED** | String | f5 to create the node on |
| lb_method | `LB_METHOD_ROUND_ROBIN` | String | Load balancing method |
| description |  | String | Pool description |
| monitors | [] | Array[String] | Monitors to check that pool members are available |
| members | [] | Array[Hash] | Members to add to the pool |

`pool_name` can be prefixed with a partition name, for example `/internal/pool_name`. Default is `/Common`.

### Example

```ruby
f5_ltm_pool 'test' do
  f5 'f5-test.test.com'
  lb_method 'LB_METHOD_ROUND_ROBIN'
  monitors ['http']
  members [
    {
      'address'   => '10.10.10.10',
      'port'      => 80,
      'enabled'   => true
    },
    {
      'address'   => '10.10.10.11',
      'port'      => 80,
      'enabled'   => true
    }
  ]
end
```

f5_ltm_monitor
--------------
`f5_ltm_monitor` - Used to manage [monitors](https://devcentral.f5.com/wiki/iControl.LocalLB__Monitor.ashx).

### Attributes

| Attr | Default/Req? | Type | Description |
|------|--------------|------|-------------|
| monitor_name | resource's name | String | Name of monitor to create on f5 |
| description |  | String | Monitor description |
| f5 | **REQUIRED** | String | f5 to create the node on |
| parent | 'https' | String | Name of parent monitor |
| interval | 5 | Integer | Monitor interval |
| timeout | 16 | Integer | Monitor timeout |
| dest_addr_type | 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT' | String | [Address types](https://devcentral.f5.com/wiki/iControl.LocalLB__AddressType.ashx) used to differentiate various node definitions |
| dest_addr_ip | '0.0.0.0' | String | IP address |
| dest_addr_port | 443 | Integer | Port |
| user_values | {} | Hash | Hash of user specific values |

`monitor_name` can be prefixed with a partition name, for example `/internal/monitor_name`. Default is `/Common`.

### Example

```ruby
f5_ltm_monitor 'test' do
  f5 'f5-test.test.com'
  parent '/Common/new_https'
  interval 20
  timeout 40
end
```

f5_ltm_virtual_server
---------------------
`f5_ltm_virtual_server` - Used to manage [virtual servers](https://devcentral.f5.com/wiki/iControl.LocalLB__VirtualServer.ashx)

### Attributes

| Attr | Default/Req? | Type | Description |
|------|--------------|------|-------------|
| vs_name | resource's name | String | Name of virtual server to create on f5 |
| f5 | REQUIRED | String | f5 to create the node on |
| destination_address | **REQUIRED** | String | Destination IP Address |
| destination_port | **REQUIRED** | Integer | Destination Port |
| destination_wildmask | '255.255.255.255' | String | Destination Wildmask as CIDR notation |
| default_pool | '' | String | Pool for virtual server to use |
| vlan_state | 'STATE_DISABLED' | String | Wether list of VLANs are disabled or enabled |
| vlans | [] | Array[String] | List of VLANs to enabled or disable based on `vlan_state` |
| profiles | [{<br/>'profile_context' => 'PROFILE_CONTEXT_TYPE_ALL',<br/>'profile_name' => '/Common/tcp'<br/>}] | Array[Hash] | Profiles to associate to virtual server |
| snat_type | 'SRC_TRANS_NONE' | String | Snat type to set on virtual server |
| snat_pool | '' | String | Snat pool to use if `snat_type` set to 'SRC_TRANS_SNATPOOL', otherwise ignored |
| default_persistence_profile | '' | String | Default persistence profile to associate with virtual server |
| fallback_persistence_profile | '' | String | Fallback persistence profile to associate with virtual server |
| rules | [] | Array[String] | iRules to associate with virtual server |
| enabled | true | true/false | Enable or disable the virtual server |
| description | '' | String | VS description |
| translate_port | '' | Boolean | Enable/Disable port translation |
| translate_address | '' | Boolean | Enable/Disable address translation |

`vs_name` can be prefixed with a partition name, for example `/internal/vs_name`. Default is `/Common`.

Originally `default_pool` was required but it's actually possible to run a VS with no pools just but using an iRule. Changed option to not required.


### Example

```ruby
f5_ltm_virtual_server 'vs_new' do
  f5 'f5-test.test.com'
  description 'Example VS for my fantastic web server'
  destination_address '10.11.10.10'
  destination_port 80
  default_pool 'new'
  enabled true
end
```

f5_ltm_string_class
-------------------
`f5_ltm_string_class` - Used to create, delete or update a string data group list

| Attr | Default/Req? | Type | Description |
|------|--------------|------|-------------|
| sc_name | resource's name | String | Name of the string class. May contain partition name. (/partition/name)|
| f5 | REQUIRED | String | f5 to create the node on |
| records | **REQUIRED** | Hash|Array | { "key1" => "value1", "key2" => "value2"} |

### Example

```ruby
entry = { "key1" => "value1", "key2" => "value2"}
f5_ltm_string_class "test002" do
  f5 "f5-test.test.com"
  records entry
  action :create
end
```

f5_ltm_address_class
-------------------
`f5_ltm_address_class` - Used to create, delete or update a list of networks

| Attr | Default/Req? | Type | Description |
|------|--------------|------|-------------|
| sc_name | resource's name | String | Name of the string class. May contain partition name. (/partition/name)|
| f5 | REQUIRED | String | f5 to create the node on |
| records | **REQUIRED** | Hash|Array | { "address" => "x.x.x.x", "netmaks" => "y.y.y.y"} |

### Example

```ruby
records = [
  {"address"=>"10.10.8.0", "netmask"=>"255.255.252.0"}, 
  {"address"=>"192.168.0.0", "netmask"=>"255.255.224.0"}
]
f5_ltm_address_class '/Common/MyAddressList' do
  f5        "f5-test.test.com"
  records   records
end
```

f5_ltm_irule
-------------------
`f5_ltm_irule` - Used to create, delete or update an iRule

| Attr | Default/Req? | Type | Description |
|------|--------------|------|-------------|
| irule_name | resource's name | String | Name of the iRule. It may contain partition name. (/partition/name)|
| f5 | REQUIRED | String | f5 to create the node on |
| content | **REQUIRED** | String | The iRule. Please note it'll fail if the the syntax is incorrect
| template | '' | String | Build up rule from template instead of inline content

### Example

```ruby
f5_ltm_irule "irule_name" do
  f5 "f5-test.test.com"
  content <<END
irule with right syntax here
END
  action :create
end
```

```ruby
f5_ltm_irule "irule_name" do
  f5 "f5-test.test.com"
  template "my_rule001.erb"
  variables { "var1" => "value1", "var2", "value2"} 
  action :create
end
```

f5_ltm_sslcert
-------------------
`f5_ltm_irule` - Used to create, delete or update an iRule

| Attr | Default/Req? | Type | Description |
|------|--------------|------|-------------|
| sslcert_name | resource's name | String | Name of the cert (ie, mysite.com)
| f5 | REQUIRED | String | f5 to create the node on |
| cert | **REQUIRED** | String | Name of the CRT file (as per files/default)
| key | optional | String | Name of the Key file (as per files/default)
| override | false| Boolean | Override cert in F5 with this one
| mode | MANAGEMENT_MODE_DEFAULT| String | Type of cert you're uploading (see below)


### Example
```ruby
f5_ltm_sslcert "/web/mysite.com" do
  f5 "f5-test.test.com"
  cert "server.crt"
  key "server.key"
  override false
end

f5_ltm_sslcert "/Common/ca-bundle" do
  f5 "f5-test.test.com"
  cert "ca-bundle.crt"
  override false
end
```

```
Valid modes are: 
  MANAGEMENT_MODE_DEFAULT
  MANAGEMENT_MODE_WEBSERVER
  MANAGEMENT_MODE_EM
  MANAGEMENT_MODE_IQUERY
  MANAGEMENT_MODE_IQUERY_BIG3D
```

Recipes
=======

* `f5-bigip::default` - install the required packages and gems required to interact with the F5 API.
* `f5-bigip::provisioner` - Make the node that is assigned this recipe an f5 provisioner system.  This recipe will dynamically define LWRPs to create the nodes, pools and virtual servers as defined by the databag value `node['f5']['provisioner']['databag']`.
  * Each item in the databag represents an F5
  * Basically lets you define your F5 with JSON
  * Example @ [test/integration/data_bags/f5-provisioner-1/test.json](test/integration/data_bags/f5-provisioner-1/test.json)

Testing
=======

Installing gems with bundler is a little different then normal in this case.  The [f5-icontrol gem](https://devcentral.f5.com/d/icontrol-ruby-library) supported by F5 is not on rubygems.org.  There IS an f5-icontrol gem on rubygems.org that is not what we want that someone else created.

So for convenience the f5-icontrol gem from F5 is included with this cookbook.  For spec testing the Gemfile references f5-icontrol.  Using the `:path` option to reference the local gem does not work per https://github.com/bundler/bundler/issues/2298.  So I used the workaround described in the referenced issue.

```
bundle install --no-cache
```

Then run the tests!
```
bundle exec foodcritic -f any -f ~FC015 -X spec .
bundle exec rspec --color --format progress
bundle exec rubocop
```

Notes on Integration Testing
----------------------------

### Why Vagrant

This cookbook uses Vagrant combined with Virtualbox and chef-minitest for testing.  It would be great to use test-kitchen instead.  Unfortunately there are several reason Vagrant is a better solution for this cookbook:

* test-kitchen does not support multiple VMs natively
* test-kitchen does not support multiple converges
* test-kitchen creates/destroys the environment every run making testing take longer
  - Testing for this cookbook can be done with Vagrant's 'provision' which leaves the VMs up and running.  test-kitchen was taking about 5min per test run whereas Vagrant takes 45 seconds per test run.

### Using Vagrant with lab F5 hardware

To use Vagrant you'll first need to make sure you have the following vagrant plugins:

* vagrant-omnibus (1.4.1 tested)
* vagrant-berkshelf (3.0.1 tested)

You'll need to modify [test/integration/data_bags/f5/creds.json](test/integration/data_bags/f5/creds.json) with the correct username/password.

Then you'll need to update `hostname` in [test/integration/data_bags/f5-provisioner-1/test.json](test/integration/data_bags/f5-provisioner-1/test.json) and [test/integration/data_bags/f5-provisioner-2/test.json](test/integration/data_bags/f5-provisioner-2/test.json) with the IP address of the F5 to connect to.

Finally, update any IPs in the minitest files with the IP of your F5: [files/default/tests/minitest/create_test.rb](files/default/tests/minitest/create_test.rb), [files/default/tests/minitest/provisioner_test.rb](files/default/tests/minitest/provisioner_test.rb)

Now you should be able to create an admin node AND run a test:
```
vagrant up admin
```

After the VM have been created subsequent testing can be done by doing:
```
vagrant provision admin
```

### Notes for maintainers with access to F5 VE Vagrant box

If you have access to an F5 VE Vagrant box

Create test environment AND run a test:
```
vagrant up
```

After the VMs have been created subsequent testing can be done by doing:
```
vagrant provision
```

License and Authors
===================

Author:: Jacob McCann (<jacob.mccann2@target.com>)

```text
Copyright:: 2013, Target Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

Partitions and iRules support
Author: Sergio Rua
```text
Copyright:: 2015, Sky Betting and Gaming

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

require 'spec_helper'

require 'chef/platform'
require 'chef/run_context'
require 'chef/resource'
require 'chef/event_dispatch/base'
require 'chef/event_dispatch/dispatcher'

require 'resource_ltm_monitor'

describe Chef::Provider::F5LtmMonitor do
  # Create a provider instance
  let(:provider) { Chef::Provider::F5LtmMonitor.new(new_resource, run_context) }

  # LoadBalancer stubbing
  let(:load_balancer) { double('F5::LoadBalancer', :client => client, :ltm => ltm) }
  let(:ltm) { double('F5::LoadBalancer::Ltm', :monitors => monitors) }
  let(:client) do
    {
      'LocalLB.Monitor' => locallb_monitor
    }
  end

  # Lets use a real Monitors object
  let(:locallb_monitor) do
    double 'LocalLB.Monitor', :get_template_list => template_list,
                              :is_template_root => is_template_root_resp,
                              :get_parent_template => parent_template_list,
                              :get_template_destination => template_destination,
                              :get_template_integer_property => template_integer_property,
                              :get_template_string_property => template_string_property
  end
  let(:template_list) do
    [
      { 'template_name' => '/Common/none', 'template_type' => 'TTYPE_NONE' },
      { 'template_name' => '/Common/firepass', 'template_type' => 'TTYPE_FIREPASS' },
      { 'template_name' => '/Common/http', 'template_type' => 'TTYPE_HTTP' },
      { 'template_name' => '/Common/http_head_f5', 'template_type' => 'TTYPE_HTTP' },
      { 'template_name' => '/Common/https', 'template_type' => 'TTYPE_HTTPS' },
      { 'template_name' => '/Common/https_443', 'template_type' => 'TTYPE_HTTPS' },
      { 'template_name' => '/Common/mon_new_defaults', 'template_type' => 'TTYPE_HTTP' },
      { 'template_name' => '/Common/test_monitor', 'template_type' => 'TTYPE_HTTPS' }
    ]
  end
  let(:monitor_names) do
    ['/Common/http_head_f5', '/Common/https_443', '/Common/mon_new_defaults', '/Common/test_monitor']
  end
  let(:is_template_root_resp) do
    [true, true, true, false, true, false, false, false]
  end
  let(:parent_template_list) do
    ['/Common/http', '/Common/https', '/Common/http', '/Common/https']
  end
  let(:template_destination) do
    [
      { 'address_type' => 'ATYPE_STAR_ADDRESS_STAR_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 0 } },
      { 'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 443 } },
      { 'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 80 } },
      { 'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 443 } }
    ]
  end
  let(:template_integer_property) do
    [{ 'type' => 'ITYPE_INTERVAL', 'value' => 10 }]
  end
  let(:template_string_property) do
    [{ 'type' => 'STYPE_SEND', 'value' => 'test' }]
  end
  let(:monitors) { F5::LoadBalancer::Ltm::Monitors.new(client) }

  # Some Chef stubbing
  let(:node) do
    node = Chef::Node.new
    node
  end
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }

  # Set current_resource and new_resource state
  let(:new_resource) do
    r = Chef::Resource::F5LtmMonitor.new('/Common/test_monitor')
    r.f5('test')
    r
  end
  let(:current_resource) do
    r = Chef::Resource::F5LtmMonitor.new('/Common/test_monitor')
    r.exists = true
    r
  end

  # Tie some things together
  before do
    allow(provider).to receive(:load_current_resource).and_return(current_resource)
    allow(provider).to receive(:load_balancer).and_return(load_balancer)
    provider.new_resource = new_resource
    provider.current_resource = current_resource
  end

  describe '#action_create' do
    describe 'manage with default values' do
      it 'creates a new monitor if not already created' do
        provider.current_resource.exists = false
        expect(locallb_monitor).to receive(:create_template)
          .with([{ 'template_name' => '/Common/test_monitor',
                   'template_type' => nil }],
                [{ 'parent_template' => 'https',
                   'interval' => 5,
                   'timeout' => 16,
                   'dest_ipport' => {
                     'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT',
                     'ipport' => {
                       'address' => '0.0.0.0',
                       'port' => 443
                     }
                   },
                   'is_read_only' => 'false',
                   'is_directly_usable' => 'true' }])
        provider.action_create
      end

      it 'does nothing if monitor is already created' do
        expect(locallb_monitor).not_to receive(:create_template)
        provider.action_create
      end
    end

    describe 'manage with user values' do
      let(:template_destination) do
        [
          { 'address_type' => 'ATYPE_STAR_ADDRESS_STAR_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 0 } },
          { 'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 443 } },
          { 'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 80 } },
          { 'address_type' => 'ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT', 'ipport' => { 'address' => '10.10.10.11', 'port' => 4443 } }
        ]
      end
      let(:parent_template_list) do
        ['/Common/http', '/Common/https', '/Common/http', '/Common/http']
      end

      before do
        allow(provider).to receive(:load_current_resource).and_call_original
        allow(locallb_monitor).to receive(:get_template_integer_property)
          .with(['/Common/test_monitor'], ['ITYPE_INTERVAL']).and_return(['value' => 10])
        allow(locallb_monitor).to receive(:get_template_integer_property)
          .with(['/Common/test_monitor'], ['ITYPE_TIMEOUT']).and_return(['value' => 31])
        provider.new_resource.parent('http')
        provider.new_resource.interval(10)
        provider.new_resource.timeout(31)
        provider.new_resource.dest_addr_type('ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT')
        provider.new_resource.dest_addr_ip('10.10.10.11')
        provider.new_resource.dest_addr_port(4443)
      end

      it 'creates a new monitor if not already created' do
        provider.current_resource.exists = false
        expect(locallb_monitor).to receive(:create_template)
          .with([{ 'template_name' => '/Common/test_monitor', 'template_type' => nil }],
                [{ 'parent_template' => 'http',
                   'interval' => 10,
                   'timeout' => 31,
                   'dest_ipport' => {
                     'address_type' => 'ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT',
                     'ipport' => {
                       'address' => '10.10.10.11',
                       'port' => 4443
                     }
                   },
                   'is_read_only' => 'false',
                   'is_directly_usable' => 'true' }])
        provider.action_create
      end

      it 'does nothing if monitor is already created' do
        provider.current_resource.parent('http')
        provider.current_resource.interval(10)
        provider.current_resource.timeout(31)
        provider.current_resource.dest_addr_type('ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT')
        provider.current_resource.dest_addr_ip('10.10.10.11')
        provider.current_resource.dest_addr_port(4443)
        provider.current_resource.user_values('STYPE_SEND' => 'test', 'STYPE_RECEIVE' => 'test_recv')
        expect(locallb_monitor).not_to receive(:create_template)
        provider.action_create
      end
    end

    describe 'managing destination' do
      it 'set destination type' do
        provider.new_resource.dest_addr_type('ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT')
        expect(locallb_monitor).to receive(:set_template_destination).with(
          ['/Common/test_monitor'],
          [{
            'address_type' => 'ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT',
            'ipport' => {
              'address' => '0.0.0.0',
              'port' => 443
            }
          }]
        )
        provider.action_create
      end

      it 'sets destination ip' do
        provider.new_resource.dest_addr_ip('10.10.10.11')
        expect(locallb_monitor).to receive(:set_template_destination).with(
          ['/Common/test_monitor'],
          [{
            'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT',
            'ipport' => {
              'address' => '10.10.10.11',
              'port' => 443
            }
          }]
        )
        provider.action_create
      end

      it 'sets destination port' do
        provider.new_resource.dest_addr_port(8888)
        expect(locallb_monitor).to receive(:set_template_destination).with(
          ['/Common/test_monitor'],
          [{
            'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT',
            'ipport' => {
              'address' => '0.0.0.0',
              'port' => 8888
            }
          }]
        )
        provider.action_create
      end

      it 'does nothing if destination set' do
        provider.current_resource.dest_addr_type('ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT')
        provider.current_resource.dest_addr_ip('10.10.10.11')
        provider.current_resource.dest_addr_port(8888)
        provider.new_resource.dest_addr_type('ATYPE_EXPLICIT_ADDRESS_EXPLICIT_PORT')
        provider.new_resource.dest_addr_ip('10.10.10.11')
        provider.new_resource.dest_addr_port(8888)
        expect(locallb_monitor).not_to receive(:set_template_destination)
        provider.action_create
      end
    end

    describe 'managing interval' do
      it 'sets interval' do
        provider.new_resource.interval(10)
        expect(locallb_monitor).to receive(:set_template_integer_property)
          .with(['/Common/test_monitor'], [{ 'type' => 'ITYPE_INTERVAL', 'value' => 10 }])
        provider.action_create
      end

      it 'does nothing if interval set' do
        provider.current_resource.interval(10)
        provider.new_resource.interval(10)
        expect(locallb_monitor).not_to receive(:set_template_integer_property)
        provider.action_create
      end
    end

    describe 'managing timeout' do
      it 'sets timeout' do
        provider.new_resource.timeout(10)
        expect(locallb_monitor).to receive(:set_template_integer_property)
          .with(['/Common/test_monitor'], [{ 'type' => 'ITYPE_TIMEOUT', 'value' => 10 }])
        provider.action_create
      end

      it 'does nothing if timeout set' do
        provider.current_resource.timeout(10)
        provider.new_resource.timeout(10)
        expect(locallb_monitor).not_to receive(:set_template_integer_property)
        provider.action_create
      end
    end

    describe 'managing parent' do
      it 'set parent template' do
        provider.new_resource.parent('/Common/http')
        expect(provider).to receive(:delete_template)
        expect(provider).to receive(:create_template)
        provider.action_create
      end

      it 'does nothing if parent template is correct' do
        provider.current_resource.parent('/Common/http')
        provider.new_resource.parent('/Common/http')
        expect(provider).not_to receive(:delete_template)
        expect(provider).not_to receive(:create_template)
        provider.action_create
      end
    end

    describe 'managing user values' do
      before do
        provider.current_resource.type('TTYPE_HTTPS')
        provider.current_resource.user_values('STYPE_SEND' => '', 'STYPE_RECEIVE' => '')
      end

      it 'sets send string' do
        provider.new_resource.user_values('STYPE_SEND' => 'test')
        expect(locallb_monitor).to receive(:set_template_string_property)
          .with(['/Common/test_monitor'], [{ 'type' => 'STYPE_SEND', 'value' => 'test' }])
        provider.action_create
      end

      it 'does nothing when send string set' do
        provider.current_resource.user_values('STYPE_SEND' => 'test')
        provider.new_resource.user_values('STYPE_SEND' => 'test')
        expect(locallb_monitor).not_to receive(:set_template_string_property)
        provider.action_create
      end

      it 'sets receive string' do
        provider.new_resource.user_values('STYPE_RECEIVE' => 'test')
        expect(locallb_monitor).to receive(:set_template_string_property)
          .with(['/Common/test_monitor'], [{ 'type' => 'STYPE_RECEIVE', 'value' => 'test' }])
        provider.action_create
      end

      it 'does nothing when receive string set' do
        provider.current_resource.user_values('STYPE_RECEIVE' => 'test')
        provider.new_resource.user_values('STYPE_RECEIVE' => 'test')
        expect(locallb_monitor).not_to receive(:set_template_string_property)
        provider.action_create
      end
    end
  end

  describe '#action_delete' do
    it 'deletes the existing monitor' do
      provider.current_resource.exists = true
      expect(locallb_monitor).to receive(:delete_template).with(['/Common/test_monitor'])
      provider.action_delete
    end

    it 'does nothing when monitor to delete do not exist' do
      provider.current_resource.exists = false
      expect(locallb_monitor).not_to receive(:delete_template)
      provider.action_delete
    end
  end
end

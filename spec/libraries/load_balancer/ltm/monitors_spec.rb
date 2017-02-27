require 'spec_helper'

describe F5::LoadBalancer::Ltm::Monitors do
  let(:client) { double('F5::IControl') }
  let(:locallb_monitor) do
    double 'LocalLB.Monitor', :get_template_list => template_list,
                              :is_template_root => is_template_root_resp,
                              :get_parent_template => parent_template_list,
                              :get_template_destination => template_destination,
                              :get_template_integer_property => [{ 'type' => 'ITYPE_INTERVAL', 'value' => 10 }],
                              :get_template_string_property => [{ 'type' => 'STYPE_SEND', 'value' => 'test' }]
  end
  let(:template_list) do
    [
      { 'template_name' => '/Common/none', 'template_type' => 'TTYPE_NONE' },
      { 'template_name' => '/Common/firepass', 'template_type' => 'TTYPE_FIREPASS' },
      { 'template_name' => '/Common/http', 'template_type' => 'TTYPE_HTTP' },
      { 'template_name' => '/Common/http_head_f5', 'template_type' => 'TTYPE_HTTP' },
      { 'template_name' => '/Common/https', 'template_type' => 'TTYPE_HTTPS' },
      { 'template_name' => '/Common/https_443', 'template_type' => 'TTYPE_HTTPS' },
      { 'template_name' => '/Common/mon_new_defaults', 'template_type' => 'TTYPE_HTTPS' },
      { 'template_name' => '/Common/mon_new', 'template_type' => 'TTYPE_HTTP' }
    ]
  end
  let(:monitor_names) do
    ['/Common/http_head_f5', '/Common/https_443', '/Common/mon_new_defaults', '/Common/mon_new']
  end
  let(:is_template_root_resp) do
    [true, true, true, false, true, false, false, false]
  end
  let(:parent_template_list) do
    ['/Common/http', '/Common/https', '/Common/https', '/Common/http']
  end
  let(:template_destination) do
    [
      { 'address_type' => 'ATYPE_STAR_ADDRESS_STAR_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 0 } },
      { 'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 443 } },
      { 'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 443 } },
      { 'address_type' => 'ATYPE_STAR_ADDRESS_EXPLICIT_PORT', 'ipport' => { 'address' => '0.0.0.0', 'port' => 8081 } }
    ]
  end
  let(:monitors) do
    F5::LoadBalancer::Ltm::Monitors.new(client)
  end

  before do
    allow(client).to receive(:[]).with('LocalLB.Monitor').and_return(locallb_monitor)
  end

  describe '#monitors' do
    it 'is an Array of F5::LoadBalancer::Ltm::Monitors::Monitor' do
      expect(monitors.monitors).to be_an(Array)
      expect(monitors.monitors).not_to be_empty

      monitors.monitors.each do |v|
        expect(v).to be_a(F5::LoadBalancer::Ltm::Monitors::Monitor)
      end
    end

    it 'is empty when no monitors are returned from f5' do
      allow(locallb_monitor).to receive(:get_template_list).and_return([])
      expect(monitors.monitors).to be_empty
    end
  end

  describe '#names' do
    it 'returns an array of the names of the monitors' do
      expect(monitors.names).to be_an(Array)
      expect(monitors.names).to eq(monitor_names)
    end
  end

  describe '#refresh_parent' do
    it 'gathers the parent template for the templates' do
      expect(locallb_monitor).to receive(:get_parent_template).with(monitor_names)
      monitors.monitors.each_with_index do |monitor, idx|
        expect(monitor).to receive(:parent=).with(parent_template_list[idx])
      end
      monitors.refresh_parent
    end
  end

  describe '#refresh_destination' do
    it 'gathers the destination for the templates' do
      expect(locallb_monitor).to receive(:get_template_destination).with(monitor_names)
      monitors.monitors.each_with_index do |monitor, idx|
        expect(monitor).to receive(:dest_addr_type=).with(template_destination[idx]['address_type'])
        expect(monitor).to receive(:dest_addr_ip=).with(template_destination[idx]['ipport']['address'])
        expect(monitor).to receive(:dest_addr_port=).with(template_destination[idx]['ipport']['port'])
      end
      monitors.refresh_destination
    end
  end

  describe '#refresh_interval' do
    it 'gathers the interval for the templates' do
      monitors.monitors.each_with_index do |monitor, _idx|
        expect(locallb_monitor).to receive(:get_template_integer_property).with([monitor.name], ['ITYPE_INTERVAL'])
        expect(monitor).to receive(:interval=).with(10)
      end
      monitors.refresh_interval
    end
  end

  describe '#refresh_timeout' do
    it 'gathers the timeout for the templates' do
      monitors.monitors.each_with_index do |monitor, _idx|
        expect(locallb_monitor).to receive(:get_template_integer_property).with([monitor.name], ['ITYPE_TIMEOUT'])
        expect(monitor).to receive(:timeout=).with(10)
      end
      monitors.refresh_timeout
    end
  end

  describe '#refresh_send_string' do
    it 'gathers send string value for appropriate monitors' do
      monitors.monitors.select { |m| %w(TTYPE_HTTP TTYPE_HTTPS TTYPE_TCP).include? m.type }.each do |mon|
        expect(locallb_monitor).to receive(:get_template_string_property).with([mon.name], ['STYPE_SEND'])
        expect(mon).to receive(:[]=).with('STYPE_SEND', 'test')
      end
      monitors.refresh_send_string
    end
  end

  describe '#refresh_receive_string' do
    it 'gathers receive string value for appropriate monitors' do
      monitors.monitors.select { |m| %w(TTYPE_HTTP TTYPE_HTTPS TTYPE_TCP).include? m.type }.each do |mon|
        expect(locallb_monitor).to receive(:get_template_string_property).with([mon.name], ['STYPE_RECEIVE'])
        expect(mon).to receive(:[]=).with('STYPE_RECEIVE', 'test')
      end
      monitors.refresh_receive_string
    end
  end
end

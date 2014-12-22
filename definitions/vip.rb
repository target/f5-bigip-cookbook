#
# Cookbook Name:: f5-bigip
# Definition:: f5_vip
#
# Copyright 2014, Target
#

define :f5_vip, :member_port => 443, :monitors => [], :lb_method => nil, :vlan_state => nil, :vlans => [],
                :destination_port => 443, :profiles => [], :snat_type => nil, :snat_pool => nil,
                :default_persistence_profile => nil, :fallback_persistence_profile => nil,
                :rules => [] do

  name = params[:name]
  name = params[:virtual_server] unless params[:virtual_server].nil?

  f5_config_sync params[:f5]

  params[:nodes].each do |node|
    f5_ltm_node "#{params[:f5]}-#{node}" do
      node_name node
      f5 params[:f5]
      notifies :run, "f5_config_sync[#{params[:f5]}]", :delayed
    end
  end

  pool_members = params[:nodes].map { |n| { 'address' => n, 'port' => params[:member_port], 'enabled' => true } }

  f5_ltm_pool "#{params[:f5]}-#{params[:pool]}" do
    pool_name params[:pool]
    f5 params[:f5]
    lb_method params[:lb_method] unless params[:lb_method].nil?
    monitors params[:monitors] unless params[:monitors].empty?
    members pool_members
    notifies :run, "f5_config_sync[#{params[:f5]}]", :delayed
  end

  f5_ltm_virtual_server "#{params[:f5]}-#{name}" do
    vs_name name
    f5 params[:f5]
    destination_address params[:destination_address]
    destination_port params[:destination_port]
    default_pool params[:pool]
    vlan_state params[:vlan_state] unless params[:vlan_state].nil?
    vlans params[:vlans] unless params[:vlans].empty?
    profiles params[:profiles] unless params[:profiles].empty?
    snat_type params[:snat_type] unless params[:snat_type].nil?
    snat_pool params[:snat_pool] unless params[:snat_pool].nil?
    default_persistence_profile params[:default_persistence_profile] unless params[:default_persistence_profile].nil?
    fallback_persistence_profile params[:fallback_persistence_profile] unless params[:fallback_persistence_profile].nil?
    rules params[:rules] unless params[:rules].empty?
    notifies :run, "f5_config_sync[#{params[:f5]}]", :delayed
  end
end

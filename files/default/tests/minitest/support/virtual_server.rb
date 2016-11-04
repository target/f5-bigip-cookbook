module Helpers
  # f5-icontrol test helper functions for virtual servers
  module VirtualServer
    def check_vs_address(client, vs, exp_address)
      begin
        dest_address = client['LocalLB.VirtualServer'].get_destination_v2([vs]).first
      rescue ::SOAP::FaultError
        refute true, "Received exception getting address for #{vs}, probably does not exist"
      end

      assert_match(%r{(^|\/)#{exp_address}$}, dest_address['address'])
    end

    def check_vs_port(client, vs, exp_port)
      begin
        dest_address = client['LocalLB.VirtualServer'].get_destination_v2([vs]).first
      rescue ::SOAP::FaultError
        refute true, "Received exception getting port for #{vs}, probably does not exist"
      end

      assert_equal exp_port, dest_address['port'].to_i
    end

    def check_vs_status(client, vs, exp_status)
      status = client['LocalLB.VirtualServer'].get_object_status([vs]).first

      if exp_status
        refute_equal 'ENABLED_STATUS_DISABLED', status['enabled_status'],
                     "Expected #{vs} to not be ENABLED_STATUS_DISABLED"
      else
        assert_equal 'ENABLED_STATUS_DISABLED', status['enabled_status'],
                     "Expected #{vs} to be ENABLED_STATUS_DISABLED"
      end
    rescue ::SOAP::FaultError
      refute true, "Received exception getting status for #{vs}, probably does not exist"
    end

    def check_vs_vlan_state(client, vs, exp_state)
      begin
        states = client['LocalLB.VirtualServer'].get_vlan([vs]).first
      rescue ::SOAP::FaultError
        refute true, "Received exception getting port for #{vs}, probably does not exist"
      end

      assert_equal exp_state, states['state']
    end

    def check_vs_vlans(client, vs, exp_vlans)
      begin
        vlans = client['LocalLB.VirtualServer'].get_vlan([vs]).first
      rescue ::SOAP::FaultError
        refute true, "Received exception getting port for #{vs}, probably does not exist"
      end

      assert_equal exp_vlans, [*vlans['vlans']]
    end
  end
end

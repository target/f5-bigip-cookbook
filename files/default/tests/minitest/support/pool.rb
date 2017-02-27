module Helpers
  # f5-icontrol test helper functions for pools
  module Pool
    def check_vs_pool(client, vs, exp_pool)
      begin
        curr_pool = client['LocalLB.VirtualServer'].get_default_pool_name([vs]).first
      rescue ::SOAP::FaultError
        refute true, "Received exception getting pool for #{vs}, probably does not exist"
      end

      assert_match(%r{(^|\/)#{exp_pool}$}, curr_pool)
    end

    def check_pool_member(client, pool, exp_member)
      members = client['LocalLB.Pool'].get_member_v2([pool]).first.map { |m| { 'address' => m['address'], 'port' => m['port'] } }

      assert members.include?(exp_member),
             "Expected to find pool member #{exp_member.inspect} but found the following instead: #{members.inspect}"
    rescue ::SOAP::FaultError
      refute true, "Received exception getting port for #{vs}, probably does not exist"
    end

    def check_pool_members(client, pool, exp_members)
      members = client['LocalLB.Pool'].get_member_v2([pool]).first.map { |m| { 'address' => m['address'], 'port' => m['port'] } }

      assert arrays_match?(members, exp_members),
             "Expected to find pool member #{exp_members.inspect}, found #{members.inspect} instead"
    rescue ::SOAP::FaultError
      refute true, "Received exception getting port for #{vs}, probably does not exist"
    end
  end
end

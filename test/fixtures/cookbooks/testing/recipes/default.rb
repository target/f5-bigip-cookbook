f5_vip 'testing' do
  f5 'test-f5.test.com'
  nodes ['10.10.10.10', '10.10.10.11']
  pool 'test-pool'
  destination_address '192.168.1.10'
end

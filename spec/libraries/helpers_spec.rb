require 'spec_helper'

module F5
  describe Helpers do
    include F5::Helpers

    describe '#check_key_nil' do
      let(:passing_test_hash) { { :test_key => 'test_val' } }
      let(:missing_key_hash) { { :test_key2 => 'test_val' } }
      let(:nil_value_hash) { { :test_key => nil } }
      it 'pass if key exists in hash and not nil' do
        expect(check_key_nil(passing_test_hash, :test_key)).to eq(true)
      end

      it 'fail if key in hash is not nil' do
        expect(check_key_nil(nil_value_hash, :test_key)).to eq(false)
      end

      it 'fail if key not in hash' do
        expect(check_key_nil(missing_key_hash, :test_key)).to eq(false)
      end
    end

    describe '#chef_vault_item' do
      it 'uses databag if dev_mode true' do
        allow_any_instance_of(F5::Helpers).to receive(:node).and_return('dev_mode' => true)
        expect(::Chef::DataBagItem).to receive(:load).and_return(true)
        chef_vault_item('test_bag', 'test_item')
      end

      it 'uses vault if dev_mode false' do
        allow_any_instance_of(F5::Helpers).to receive(:node).and_return('dev_mode' => false)
        expect(::ChefVault::Item).to receive(:load).and_return(true)
        chef_vault_item('test_bag', 'test_item')
      end
    end

    describe '.soap_mapping_to_hash' do
      # let(:soap_mapping_obj) do
      #   s = SOAP::Mapping::Object.new
      #   s['test_key'] = 'test_val'
      #   s
      # end

      # Need to figure out creating SOAP::Mapping::Object properly to be able to test
      # it 'converts soap mapping to a hash' do
      #   expect(F5::Helpers.soap_mapping_to_hash(soap_mapping_obj)).to eq([])
      # end
      it 'processes arrays' do
        expect(F5::Helpers.soap_mapping_to_hash([123, 234])).to eq([123, 234])
      end

      it 'passes through objects that are not SOAP::Mapping::Object' do
        expect(F5::Helpers.soap_mapping_to_hash(123)).to eq(123)
      end
    end
  end
end

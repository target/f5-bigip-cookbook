#
# Author:: Jacob McCann (<jacob.mccann2@target.com>)
#
# Copyright:: 2015, Target Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe Chef::Resource::F5LtmNode do
  let(:new_resource) do
    r = Chef::Resource::F5LtmNode.new('node1.test.com')
    r.f5('test')
    r
  end

  let(:provider) { Chef::Provider::F5LtmNode.new(new_resource, run_context) }
  let(:node) { Chef::Node.new }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }

  describe 'setting supported default values from node attributes' do
    it "has parameter 'node_name' default to the resource name" do
      expect(new_resource.node_name).to eq 'node1.test.com'
    end

    it "has parameter 'address' default to the node_name" do
      new_resource.node_name('new_node.test.com')
      expect(new_resource.address).not_to eq 'node1.test.com'
      expect(new_resource.address).to eq 'new_node.test.com'
    end

    it "has parameter 'enabled' default to true" do
      expect(new_resource.enabled).to eq true
    end
  end

  it "requires parameter 'f5' to be set" do
    r = Chef::Resource::F5LtmNode.new('node1.test.com')
    p = Chef::Provider::F5LtmNode.new(r, run_context)
    expect { p.load_current_resource }.to raise_error(Chef::Exceptions::ValidationFailed, 'f5 is required')
  end

  it "can set parameter 'f5'" do
    expect(new_resource.f5).to eq 'test'
  end

  it "can set parameter 'node_name'" do
    expect(new_resource.node_name('new_node.test.com')).to eq 'new_node.test.com'
    expect(new_resource.node_name).to eq 'new_node.test.com'
  end

  it "can set parameter 'address'" do
    expect(new_resource.address('10.10.10.10')).to eq '10.10.10.10'
    expect(new_resource.address).to eq '10.10.10.10'
  end

  it "can set parameter 'enabled'" do
    expect(new_resource.enabled).to eq true
    expect(new_resource.enabled(false)).to eq false
    expect(new_resource.enabled).to eq false
  end
end

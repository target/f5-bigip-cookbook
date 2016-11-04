#
# Cookbook Name:: f5-bigip
# Library:: matchers
#
# Copyright 2014, Target Corporation
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

if defined?(ChefSpec)
  ChefSpec.define_matcher :f5_ltm_monitor
  ChefSpec.define_matcher :f5_ltm_node
  ChefSpec.define_matcher :f5_ltm_pool
  ChefSpec.define_matcher :f5_ltm_virtual_server
  ChefSpec.define_matcher :f5_config_sync

  def create_f5_ltm_monitor(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_ltm_monitor, :create, resource_name)
  end

  def delete_f5_ltm_monitor(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_ltm_monitor, :delete, resource_name)
  end

  def create_f5_ltm_node(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_ltm_node, :create, resource_name)
  end

  def delete_f5_ltm_node(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_ltm_node, :delete, resource_name)
  end

  def create_f5_ltm_pool(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_ltm_pool, :create, resource_name)
  end

  def delete_f5_ltm_pool(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_ltm_pool, :delete, resource_name)
  end

  def clear_f5_ltm_pool(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_ltm_pool, :clear, resource_name)
  end

  def create_f5_ltm_virtual_server(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_ltm_virtual_server, :create, resource_name)
  end

  def delete_f5_ltm_virtual_server(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_ltm_virtual_server, :delete, resource_name)
  end

  def run_f5_config_sync(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:f5_config_sync, :run, resource_name)
  end
end

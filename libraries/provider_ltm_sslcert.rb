#
# Author:: Sergio Rua <sergio@rua.me.uk>
# Cookbook Name:: f5-bigip
# Provider:: ltm_node
#
# Copyright:: 2015 Sky Betting and Gaming
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

require 'erb'
require 'ostruct'

class Chef
  class Provider
    #
    # Chef Provider for F5 LTM Node
    #
    class F5LtmSslcert < Chef::Provider
      include F5::Loader

      # Support whyrun
      def whyrun_supported?
        false
      end

      def load_current_resource
        @current_resource = Chef::Resource::F5LtmSslcert.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.key(@new_resource.key)
        @current_resource.crt(@new_resource.crt)
        @current_resource.sslcert_name(@new_resource.sslcert_name)
        @current_resource.override(@new_resource.override)
        @current_resource.mode(@new_resource.mode)


        load_balancer.change_folder(@new_resource.sslcert_name)

        if @new_resource.sslcert_name.include?('/')
          cert_name = @new_resource.sslcert_name
        else
          cert_name = "/#{load_balancer.active_folder}/#{@new_resource.sslcert_name}"
        end

        # Important: .query_rule will not find the rule if the content of the rule is empty
        #            Pretty bizare behaviour in the API we'll have to work with
        certs = load_balancer.client['Management.KeyCertificate'].get_certificate_list(@new_resource.mode)
        keys  = load_balancer.client['Management.KeyCertificate'].get_key_list(@new_resource.mode)

        if certs.include?(cert_name) and
            keys.include?(cert_name)
            
          @current_resource.exists = true
          @current_resource.update = false
        else
          @current_resource.exists = false
          @current_resource.update = false
        end

        @current_resource
      end

      def action_update
        current_resource.update = true
        new_resource.override = true
        update_sslcert
      end

      def action_create
        if current_resource.update and current_resource.override
          update_sslcert
        elsif not current_resource.exists
          create_sslcert
        end
      end

      def action_delete
        delete_sslcert if current_resource.exists
      end

      private

      def load_file_contents(filename, cookb=nil)
        cook = cookbook_name if cookb.nil?
        cb = run_context.cookbook_collection[cook]

        f = cb.file_filenames.find { |t| ::File.basename(f) == filename }

        fail("#{f} not found on cookbook #{cook}") if f.nil?

        if not ::File.exists?(f)
          fail("Cannot read #{f}")
        end
        Chef::Log.info("Loading Cert / Key from #{f}")
        return ::File.read(f)
      end

      #
      # Update Key and Cert
      #
      def update_sslcert
        converge_by("Update Key/Cert #{new_resource}") do
          Chef::Log.info "Update #{new_resource}"

          pemCrt = load_file_contents(new_resource.crt)
          load_balancer.client['Management.KeyCertificate'].certificate_import_from_pem(
            new_resource.mode,
            [new_resource.sslcert_name],
            [pemCrt],
            new_resource.override
          )

          pemKey = load_file_contents(new_resource.key)
          load_balancer.client['Management.KeyCertificate'].key_import_from_pem(
            new_resource.mode,
            [new_resource.sslcert_name],
            [pemKey],
            new_resource.override
          )
          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Create a new Cert
      #
      def create_sslcert
        converge_by("Create Cert #{new_resource}") do
          Chef::Log.info "Create #{new_resource}"

          update_sslcert

          new_resource.updated_by_last_action(true)
        end
      end

      #
      # Delete node
      #
      def delete_sslcert
        converge_by("Delete #{new_resource}") do
          Chef::Log.info "Delete #{new_resource}"
          load_balancer.client['Management.KeyCertificate'].certicate_delete(new_resource.mode, [new_resource.sslcert_name])
          load_balancer.client['Management.KeyCertificate'].key_delete(new_resource.mode, [new_resource.sslcert_name])

          new_resource.updated_by_last_action(true)
        end
      end
    end
  end
end

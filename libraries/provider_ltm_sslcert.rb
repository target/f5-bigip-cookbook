#
# Author:: Sergio Rua <sergio@rua.me.uk>
# Cookbook Name:: f5-bigip
# Provider:: ltm_sslcert
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
    # Chef Provider for F5 LTM SSL Cert
    #
    class F5LtmSslcert < Chef::Provider
      include F5::Loader

      # Support whyrun
      def whyrun_supported?
        false
      end

      def load_current_resource # rubocop:disable AbcSize, MethodLength
        @current_resource = Chef::Resource::F5LtmSslcert.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.key(@new_resource.key)
        @current_resource.cert(@new_resource.cert)
        @current_resource.sslcert_name(@new_resource.sslcert_name)
        @current_resource.override(@new_resource.override)
        @current_resource.mode(@new_resource.mode)
        # default
        @current_resource.exists_cert = false
        @current_resource.exists_key  = false
        @current_resource.update_key  = false
        @current_resource.update_cert = false

        load_balancer.change_folder(@new_resource.sslcert_name)

        cert_name = if @new_resource.sslcert_name.include?('/')
                      @new_resource.sslcert_name
                    else
                      "/#{load_balancer.active_folder}/#{@new_resource.sslcert_name}"
                    end

        # LOGIC: cert is mandatory, key is optional
        cert = load_balancer.client['Management.KeyCertificate'].get_certificate_list(@new_resource.mode).find { |c| c.certificate.cert_info.id == cert_name }
        key = nil
        if @new_resource.key != ''
          key = load_balancer.client['Management.KeyCertificate'].get_key_list(@new_resource.mode).find { |c| c.key_info.id == cert_name }
        end

        if cert
          @current_resource.exists_cert = true
          @current_resource.update_cert = @new_resource.override
        end
        if key
          @current_resource.exists_key = true
          @current_resource.update_key = @new_resource.override
        end

        @current_resource
      end

      def action_update
        current_resource.update_key  = true
        current_resource.update_cert = true
        new_resource.override = true
        update_sslcert
      end

      def action_create
        if (current_resource.update_key || current_resource.update_cert) && current_resource.override
          update_sslcert
        elsif !current_resource.exists_key || !current_resource.exists_cert
          create_sslcert
        end
      end

      def action_delete
        delete_sslcert if current_resource.exists_key || current_resource.exists_cert
      end

      private

      def load_file_contents(filename, cookb = nil) # rubocop:disable AbcSize
        cook = cookbook_name if cookb.nil?
        cb = run_context.cookbook_collection[cook]

        f = cb.file_filenames.find { |t| ::File.basename(t) == filename }

        raise("#{f} not found on cookbook #{cook}") if f.nil?
        raise("Cannot read #{f}") unless ::File.exist?(f)

        Chef::Log.info("Loading Cert / Key from #{f}")
        ::File.read(f)
      end

      #
      # Update Key and Cert
      #
      def update_sslcert # rubocop:disable AbcSize, MethodLength
        converge_by("Update Key/Cert #{new_resource}") do
          Chef::Log.info "Update #{new_resource}"

          if new_resource.cert
            pem_crt = load_file_contents(new_resource.cert)
            load_balancer.client['Management.KeyCertificate'].certificate_import_from_pem(
              new_resource.mode,
              [new_resource.sslcert_name],
              [pem_crt],
              new_resource.override
            )
          end

          if new_resource.key
            pem_key = load_file_contents(new_resource.key)
            load_balancer.client['Management.KeyCertificate'].key_import_from_pem(
              new_resource.mode,
              [new_resource.sslcert_name],
              [pem_key],
              new_resource.override
            )
          end

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
      # Delete cert
      #
      def delete_sslcert # rubocop:disable AbcSize
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

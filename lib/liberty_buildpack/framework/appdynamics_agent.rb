# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2016 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/framework'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/download'
require 'liberty_buildpack/container/common_paths'
require 'liberty_buildpack/services/vcap_services'
require 'liberty_buildpack/container/container_utils'

module LibertyBuildpack::Framework

  #------------------------------------------------------------------------------------
  # The AppDynamicsAgent class that provides Appdynamics Agent resources as a framework to applications
  #------------------------------------------------------------------------------------
  class AppDynamicsAgent

    #-----------------------------------------------------------------------------------------
    # Creates an instance, passing in a context of information available to the component
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Hash] :configuration the properties provided by the user
    # @option context [CommonPaths] :common_paths the set of paths common across components that components should reference
    # @option context [Hash] :vcap_application the application information provided by cf
    # @option context [Hash] :vcap_services the services bound to the application provided by cf
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    #-----------------------------------------------------------------------------------------
    def initialize(context = {})
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @configuration = context[:configuration]
      @common_paths = context[:common_paths] || LibertyBuildpack::Container::CommonPaths.new
      @vcap_application = context[:vcap_application]
      @vcap_services = context[:vcap_services]
      @services = @vcap_services ? LibertyBuildpack::Services::VcapServices.new(@vcap_services) : LibertyBuildpack::Services::VcapServices.new({})
      @java_opts = context[:java_opts]
    end

    #-----------------------------------------------------------------------------------------
    # Determines if the application's VCAP environment and the configured Appdynamics configuration
    # is available for the Appdynamics framework to provide a configured Appdynamics agent. Valid
    # detect is based on VCAP_SERVICES, VCAP_APPLICATION, and the repository root index.yml
    # defined by the Appdynamics configuration.
    #
    # @return [String] the detected versioned ID if the environment and config are valid, otherwise nil
    #------------------------------------------------------------------------------------------
    def detect
      app_has_name? && appdynamics_service_exist? ? process_config : nil
    end

    #-----------------------------------------------------------------------------------------
    # Create the appdynamics_agent directory and its contents for the app droplet.
    #------------------------------------------------------------------------------------------
    def compile
      if @app_dir.nil?
        raise 'app directory must be provided'
      elsif @version.nil? || @uri.nil?
        raise "Version #{@version}, uri #{@uri} is not available, detect needs to be invoked"
      end

      appdynamics_home = File.join(@app_dir, APPDYNAMICS_HOME_DIR)
      FileUtils.mkdir_p(appdynamics_home)
      download_and_install_agent(appdynamics_home)
      copy_agent_config(appdynamics_home)
    end

    #-----------------------------------------------------------------------------------------
    # Create the Appdynamics agent options appended as java_opts.
    #------------------------------------------------------------------------------------------
    def release
      app_dir = @common_paths.relative_location
      appdynamics_home_dir = File.join(app_dir, APPDYNAMICS_HOME_DIR)
      appd_agent = File.join(appdynamics_home_dir, 'javaagent.jar')

      @java_opts << "-javaagent:#{appd_agent}"
      @java_opts << '-Dorg.osgi.framework.bootdelegation=com.sun.btrace, com.singularity.*'

      credentials = @services.find_service(FILTER)['credentials']

      application_name @java_opts, credentials
      tier_name @java_opts, credentials
      node_name @java_opts, credentials
      account_access_key @java_opts, credentials
      account_name @java_opts, credentials
      host_name @java_opts, credentials
      port @java_opts, credentials
      ssl_enabled @java_opts, credentials
      @java_opts
    end

    private

    # Name of the Appdynamics service
    FILTER = /app[-]?dynamics/

    # Appdynamics's directory of artifacts in the droplet
    APPDYNAMICS_HOME_DIR = '.appdynamics_agent'.freeze

    #-----------------------------------------------------------------------------------------
    # Determines if the Appdynamics service is included in VCAP_SERVICES based on whether the
    # service entry has valid entries.
    #
    # @return [Boolean]  true if the app is bound to a Appdynamics service
    #------------------------------------------------------------------------------------------
    def appdynamics_service_exist?
      @services.one_service?(FILTER, 'host-name')
    end

    #-----------------------------------------------------------------------------------------
    # Determines if the application name is available from VCAP_APPLICATION.
    #
    # @return [Boolean]  true if the app is bound to a Appdynamics service
    #------------------------------------------------------------------------------------------
    def app_has_name?
      !@vcap_application.nil? && !vcap_app_name.nil? && !vcap_app_name.empty?
    end

    #-----------------------------------------------------------------------------------------
    # The application name that's made available from VCAP_APPLICATION.
    #
    # @return [String] the application name from VCAP_APPLICATION
    #------------------------------------------------------------------------------------------
    def vcap_app_name
      @vcap_application['application_name']
    end

    def application_name(java_opts, credentials)
      name = credentials['application-name'] || @configuration['default_application_name'] ||
        vcap_app_name
      java_opts << "-Dappdynamics.agent.applicationName=#{name}"
    end

    def account_access_key(java_opts, credentials)
      account_access_key = credentials['account-access-key']
      java_opts << "-Dappdynamics.agent.accountAccessKey=#{account_access_key}" if account_access_key
    end

    def account_name(java_opts, credentials)
      account_name = credentials['account-name']
      java_opts << "-Dappdynamics.agent.accountName=#{account_name}" if account_name
    end

    def host_name(java_opts, credentials)
      host_name = credentials['host-name']
      raise "'host-name' credential must be set" unless host_name
      java_opts << "-Dappdynamics.controller.hostName=#{host_name}"
    end

    def node_name(java_opts, credentials)
      name = credentials['node-name'] || @configuration['default_node_name'] ||
        vcap_app_name
      java_opts << "-Dappdynamics.agent.nodeName=#{name}"
    end

    def port(java_opts, credentials)
      port = credentials['port']
      java_opts << "-Dappdynamics.controller.port=#{port}" if port
    end

    def ssl_enabled(java_opts, credentials)
      ssl_enabled = credentials['ssl-enabled']
      java_opts << "-Dappdynamics.controller.ssl.enabled=#{ssl_enabled}" if ssl_enabled
    end

    def tier_name(java_opts, credentials)
      name = credentials['tier-name'] || @configuration['default_tier_name'] ||
        vcap_app_name
      java_opts << "-Dappdynamics.agent.tierName=#{name}"
    end

    #-----------------------------------------------------------------------------------------
    # Processes the Appdynamics configuration to obtain the corresponding version and uri of the
    # Appdynamics agent zip in the repository root. If the configuration can be processed and the
    # uri contains a valid Appdynamics agent zip name, the versioned ID is returned and configuration
    # data is initialized.
    #
    # @return [String] the Appdynamics version ID
    #------------------------------------------------------------------------------------------
    def process_config
      begin
        @version, @uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(@configuration)
      rescue => e
        @logger.error("Unable to process the configuration for the AppDynamics Agent framework. #{e.message}")
      end

      @version.nil? ? nil : "app-dynamics-#{@version}"
    end

    #-----------------------------------------------------------------------------------------
    # Copies the agent configuration from the buildpack resources directory to the application's droplet.
    #------------------------------------------------------------------------------------------
    def copy_agent_config(target_dir)
      agent_resource = File.join('..', '..', '..', 'resources', 'appdynamics_agent').freeze
      agent_resource_path = File.expand_path(agent_resource, File.dirname(__FILE__))

      # only grab the files in the Appdynamics Agent template
      FileUtils.cp_r(agent_resource_path + '/.', target_dir)
    end

    #-----------------------------------------------------------------------------------------
    # Download the agent library from the repository as specified in the Appdynamics configuration.
    #------------------------------------------------------------------------------------------
    def download_and_install_agent(home)
      LibertyBuildpack::Util.download_zip(@version, @uri, 'AppDynamics Agent', home)
    rescue => e
      raise "Unable to download the AppDynamics Agent zip. Ensure that the agent zip at #{@uri} is available and accessible. #{e.message}"
    end
  end
end

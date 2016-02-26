# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014-2015 the original author or authors.
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
  # The AppdynamicsAgent class that provides Appdynamics Agent resources as a framework to applications
  #------------------------------------------------------------------------------------
  class AppdynamicsAgent

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
      elsif @version.nil? || @uri.nil? || @appdynamics_jar.nil?
        raise "Version #{@version}, uri #{@uri}, or Appdynamics agent jar name #{@appdynamics_jar} is not available, detect needs to be invoked"
      end

      appdynamics_home = File.join(@app_dir, APPDYNAMICS_HOME_DIR)
      FileUtils.mkdir_p(appdynamics_home)
      download_agent(@version, @uri, @appdynamics_jar, appdynamics_home)
      copy_agent_config(appdynamics_home)
    end

    #-----------------------------------------------------------------------------------------
    # Determines the location of javaagent for Appdynamics.
    #------------------------------------------------------------------------------------------
    def get_java_agent
      String.new(Dir['app/**/appdynamics_agent/**/javaagent.jar'].reject { |file| file.include?('threadprofiler') } [0])
    end

    #-----------------------------------------------------------------------------------------
    # Create the Appdynamics agent options appended as java_opts.
    #------------------------------------------------------------------------------------------
    def release
      appd_agent = getJavaAgent
      appdynamics_home_dir = File.join(@app_dir, APPDYNAMICS_HOME_DIR)
      appdynamics_logs_dir = @common_paths.log_directory
      application_name = @vcap_application['application_name']
      account_access_key = @vcap_services['appdynamics'][0]['credentials']['account-access-key']
      account_name = @vcap_services['appdynamics'][0]['credentials']['account-name']
      host_name = @vcap_services['appdynamics'][0]['credentials']['host-name']
      node_name = application_name
      port = @vcap_services['appdynamics'][0]['credentials']['port']
      ssl_enabled = @vcap_services['appdynamics'][0]['credentials']['ssl-enabled']
      tier_name = application_name
      @java_opts << "-Dappdynamics.home=#{appdynamics_home_dir}"
      @java_opts << "-Dappdynamics.config.app_name=#{vcap_app_name}"
      @java_opts << "-Dappdynamics.config.log_file_path=#{appdynamics_logs_dir}"
      @java_opts << "-Dappdynamics.agent.applicationName=#{application_name}"
      @java_opts << "-Dappdynamics.agent.accountAccessKey=#{account_access_key}"
      @java_opts << "-Dappdynamics.agent.accountName=#{account_name}"
      @java_opts << "-Dappdynamics.controller.hostName=#{host_name}"
      @java_opts << "-Dappdynamics.agent.nodeName=#{node_name}"
      @java_opts << "-Dappdynamics.controller.port=#{port}"
      @java_opts << "-Dappdynamics.controller.ssl.enabled=#{ssl_enabled}"
      @java_opts << "-Dappdynamics.agent.tierName=#{tier_name}"
      @java_opts << "-javaagent:/#{appd_agent}" if appd_agent.length >= 40
    end

    # Name of the Appdynamics service
    APPDYNAMICS_SERVICE_NAME = 'appdynamics'.freeze

    # VCAP_SERVICES keys
    LICENSE_KEY = 'licenseKey'.freeze

    # VCAP_APPLICATION keys
    APPLICATION_NAME_KEY = 'application_name'.freeze

    # Appdynamics's directory of artifacts in the droplet
    APPDYNAMICS_HOME_DIR = 'appdynamics_agent'.freeze

    #-----------------------------------------------------------------------------------------
    # Determines if the Appdynamics service is included in VCAP_SERVICES based on whether the
    # service entry has valid entries.
    #
    # @return [Boolean]  true if the app is bound to a Appdynamics service
    #------------------------------------------------------------------------------------------
    def appdynamics_service_exist?
      @services.one_service?(APPDYNAMICS_SERVICE_NAME)
    end

    #-----------------------------------------------------------------------------------------
    # Determines if the application name is available from VCAP_APPLICATION.
    #
    # @return [Boolean]  true if the app is bound to a Appdynamics service
    #------------------------------------------------------------------------------------------
    def app_has_name?
      !@vcap_application.nil? && !@vcap_application[APPLICATION_NAME_KEY].nil? && !@vcap_application[APPLICATION_NAME_KEY].empty?
    end

    #-----------------------------------------------------------------------------------------
    # The application name that's made available from VCAP_APPLICATION.
    #
    # @return [String] the application name from VCAP_APPLICATION
    #------------------------------------------------------------------------------------------
    def vcap_app_name
      @vcap_application[APPLICATION_NAME_KEY]
    end

    #-----------------------------------------------------------------------------------------
    # Processes the Appdynamics configuration to obtain the corresponding version and uri of the
    # Appdynamics agent jar in the repository root. If the configuration can be processed and the
    # uri contains a valid Appdynamics agent jar name, the versioned ID is returned and configuration
    # data is initialized.
    #
    # @return [String] the Appdynamics version ID
    #------------------------------------------------------------------------------------------
    def process_config
      begin
        @version, @uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(@configuration)
        id_pattern = 'app-dynamics'
        jar_pattern = "#{id_pattern}-#{@version}.zip"
        # get the jar name from the uri, ensuring that the jar is a new-relic jar eg: new-relic-3.11.0.jar
        if !@uri.nil? && @uri.split('/').last.match(/#{jar_pattern}/)
          @appdynamics_jar = jar_pattern
        else
          @logger.error("The #{id_pattern}.jar  #{jar_pattern}  format could not be matched from the uri #{@uri}")
        end
      rescue => e
        @logger.debug("Contents of the Appdynamics Agent configuration #{@configuration}")
        @logger.error("Unable to process the configuration for the Appdynamics Agent framework. #{e.message}")
      end
        @appdynamics_jar.nil? ? nil : id_pattern
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
    def download_agent(version_desc, uri_source, target_jar_name, target_dir)
      LibertyBuildpack::Util.download(version_desc, uri_source, target_jar_name, target_jar_name, target_dir)
      LibertyBuildpack::Container::ContainerUtils.unzip(File.join(target_dir, 'app-dynamics-3.8.4.zip'), target_dir)
    rescue => e
      raise "Unable to download the Appdynamics Agent jar. Ensure that the agent jar at #{uri_source} is available and accessible. #{e.message}"
    end
  end
end

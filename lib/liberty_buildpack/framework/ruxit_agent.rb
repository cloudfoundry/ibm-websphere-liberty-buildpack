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

module LibertyBuildpack::Framework

  #------------------------------------------------------------------------------------
  # The RuxitAgent class that provides Dynatrace Ruxit Agent resources as a framework to applications
  #------------------------------------------------------------------------------------
  class RuxitAgent

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
    # Determines if the application's VCAP environment and the configured Ruxit configuration
    # is available for the Ruxit framework to provide a configured Ruxit agent. Valid
    # detect is based on VCAP_SERVICES, VCAP_APPLICATION, and the repository root index.yml
    # defined by the Ruxit configuration.
    #
    # @return [String] the detected versioned ID if the environment and config are valid, otherwise nil
    #------------------------------------------------------------------------------------------
    def detect
      ruxit_service_exist? ? process_config : nil
    end

    #-----------------------------------------------------------------------------------------
    # Create the ruxit_agent directory and its contents for the app droplet.
    #------------------------------------------------------------------------------------------
    def compile
      if @app_dir.nil?
        raise 'app directory must be provided'
      elsif @version.nil? || @uri.nil?
        raise "Version #{@version} or uri #{@uri} is not available, detect needs to be invoked"
      end

      # create a ruxit home dir in the droplet
      ruxit_home = File.join(@app_dir, RUXIT_HOME_DIR)
      FileUtils.mkdir_p(ruxit_home)
      @logger.debug("Ruxit home directory: #{ruxit_home}")

      # export ruxit specific environment variables
      export_ruxit_environment_variables

      download_and_install_agent(ruxit_home)
    end

    #-----------------------------------------------------------------------------------------
    # Create the Ruxit agent options appended as java_opts.
    #------------------------------------------------------------------------------------------
    def release
      credentials = @services.find_service(RUXIT_SERVICE_NAME)['credentials']

      # ruxit paths within the droplet
      pwd = ENV['PWD']
      ruxit_home_dir = "#{pwd}/app/#{RUXIT_HOME_DIR}"
      ruxit_agent = File.join(ruxit_home_dir, 'agent', lib_name, 'libruxitagentloader.so')
      @logger.debug("ruxit_agent: #{ruxit_agent}")

      # create the ruxit agent command as java_opts
      @java_opts << "-agentpath:#{ruxit_agent}=#{get_service_options(credentials)}"
    end

    private

    # Name of the dynatrace service
    RUXIT_SERVICE_NAME = /ruxit/

    # VCAP_SERVICES keys
    CREDENTIALS_KEY = 'credentials'.freeze
    SERVER = 'server'.freeze
    TENANT = 'tenant'.freeze
    TENANTTOKEN = 'tenanttoken'.freeze

    # ruxit's directory of artifacts in the droplet
    RUXIT_HOME_DIR = '.ruxit_agent'.freeze

    # ruxit ENV variables
    RUXIT_APPLICATION_ID = 'RUXIT_APPLICATIONID'.freeze
    RUXIT_CLUSTER_ID = 'RUXIT_CLUSTER_ID'.freeze
    RUXIT_HOST_ID = 'RUXIT_HOST_ID'.freeze

    #------------------------------------------------------------------------------------------
    # Determines the system architecture.
    #
    # @return [String] the system architecture type
    #------------------------------------------------------------------------------------------
    def architecture
      `uname -m`.strip
    end

    #------------------------------------------------------------------------------------------
    # Download the agent library from the repository as specified in the ruxit configuration.
    #------------------------------------------------------------------------------------------
    def download_and_install_agent(ruxit_home)
      LibertyBuildpack::Util.download_zip(@version, @uri, 'Ruxit Agent', ruxit_home)
    rescue => e
      raise "Unable to download the Ruxit Agent. Ensure that the agent at #{@uri} is available and accessible. #{e.message}"
    end

    #------------------------------------------------------------------------------------------
    # Determines if the ruxit service is included in VCAP_SERVICES based on whether the
    # service entry has valid entries.
    #
    # @return [Boolean] true if the app is bound to a ruxit service
    #------------------------------------------------------------------------------------------
    def ruxit_service_exist?
      @services.one_service?(RUXIT_SERVICE_NAME, TENANT, TENANTTOKEN)
    end

    #------------------------------------------------------------------------------------------
    # Retrieves Ruxit options from the ruxit service in VCAP_SERVICES.
    #
    # @return [String] options string to be appended to java agent options
    #------------------------------------------------------------------------------------------
    def get_service_options(credentials)
      begin
        @ruxit_service = @services.find_service(RUXIT_SERVICE_NAME)
        @ruxit_options = "#{SERVER}=#{server(credentials)},#{TENANT}=#{tenant(credentials)},#{TENANTTOKEN}=#{tenanttoken(credentials)}"
      rescue => e
        @logger.error("Unable to process the service options for the Ruxit Agent framework. #{e.message}")
      end

      @ruxit_options.nil? ? nil : @ruxit_options
    end

    #------------------------------------------------------------------------------------------
    # Determines the proper library name to use based on system architecture.
    #
    # @return [String] the library name
    #------------------------------------------------------------------------------------------
    def lib_name
      architecture == 'x86_64' || architecture == 'i686' ? 'lib64' : 'lib'
    end

    #-----------------------------------------------------------------------------------------
    # Processes the dynatrace configuration to obtain the corresponding version and uri of the
    # dynatrace agent jar in the repository root. If the configuration can be processed and the
    # uri contains a valid dynatrace agent jar name, the versioned ID is returned and configuration
    # data is initialized.
    #
    # @return [String] the dynatrace version ID
    #------------------------------------------------------------------------------------------
    def process_config
      begin
        @version, @uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(@configuration)
      rescue => e
        @logger.error("Unable to process the configuration for the Ruxit Agent framework. #{e.message}")
      end

      @version.nil? ? nil : "ruxit-agent-#{@version}"
    end

    # Create .profile.d/0ruxit-env.sh with the ruxit environment variables
    #
    # @return [void]
    def export_ruxit_environment_variables
      profiled_dir = File.join(@app_dir, '.profile.d')
      FileUtils.mkdir_p(profiled_dir)

      variables = {}
      variables[RUXIT_APPLICATION_ID] = application_id
      variables[RUXIT_CLUSTER_ID] = cluster_id
      variables[RUXIT_HOST_ID] = host_id

      @logger.debug { "Ruxit environment variables: #{variables}" }

      env_file_name = File.join(profiled_dir, '0ruxit-env.sh')
      env_file = File.new(env_file_name, 'w')
      variables.each do |key, value|
        env_file.puts("export #{key}=\"${#{key}:-#{value}}\"") # "${VAR1:-default value}"
      end
      env_file.close
    end

    def application_id
      @vcap_application['application_name']
    end

    def cluster_id
      @vcap_application['application_name']
    end

    def host_id
      "#{@vcap_application['application_name']}_${CF_INSTANCE_INDEX}"
    end

    def server(credentials)
      credentials[SERVER] || "https://#{tenant(credentials)}.live.ruxit.com:443/communication"
    end

    def tenant(credentials)
      credentials[TENANT]
    end

    def tenanttoken(credentials)
      credentials[TENANTTOKEN]
    end

  end
end

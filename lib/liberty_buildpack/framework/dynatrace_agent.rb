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
  # The DynaTraceAgent class that provides Dyna Trace Agent resources as a framework to applications
  #------------------------------------------------------------------------------------
  class DynaTraceAgent

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
    # Determines if the application's VCAP environment and the configured dynatrace configuration
    # is available for the dynatrace framework to provide a configured dynatrace agent. Valid
    # detect is based on VCAP_SERVICES, VCAP_APPLICATION, and the repository root index.yml
    # defined by the dynatrace configuration.
    #
    # @return [String] the detected versioned ID if the environment and config are valid, otherwise nil
    #------------------------------------------------------------------------------------------
    def detect
      dt_service_exist? ? process_config : nil
    end

    #-----------------------------------------------------------------------------------------
    # Create the dynatrace_agent directory and its contents for the app droplet.
    #------------------------------------------------------------------------------------------
    def compile
      if @app_dir.nil?
        raise 'app directory must be provided'
      elsif @version.nil? || @uri.nil?
        raise "Version #{@version} or uri #{@uri} is not available, detect needs to be invoked"
      end

      # create a dynatrace home dir in the droplet
      dt_home = File.join(@app_dir, DT_HOME_DIR)
      FileUtils.mkdir_p(dt_home)

      @logger.debug("Dynatrace home directory: #{dt_home}")

      download_and_install_agent(dt_home)
    end

    #-----------------------------------------------------------------------------------------
    # Create the dynatrace agent options appended as java_opts.
    #------------------------------------------------------------------------------------------
    def release
      # dynatrace paths within the droplet
      pwd = ENV['PWD']
      dt_home_dir = "#{pwd}/app/#{DT_HOME_DIR}"
      dt_agent = File.join(dt_home_dir, 'agent', agent_unpack_path, lib_name, 'libdtagent.so')
      @logger.debug("dt_agent: #{dt_agent}")

      # create the dynatrace agent command as java_opts
      @java_opts << "-agentpath:#{dt_agent}=#{get_service_options}"
    end

    private

    # Name of the dynatrace service
    DT_SERVICE_NAME = 'dynatrace'.freeze

    # Name of the default dynatrace profile
    DT_DEFAULT_PROFILE_NAME = 'Monitoring'.freeze

    # VCAP_SERVICES keys
    CREDENTIALS_KEY = 'credentials'.freeze
    OPTIONS_KEY = 'options'.freeze
    PROFILE_KEY = 'profile'.freeze
    SERVER_KEY = 'server'.freeze

    # dynatrace's directory of artifacts in the droplet
    DT_HOME_DIR = '.dynatrace_agent'.freeze

    #------------------------------------------------------------------------------------------
    # Determines the system architecture.
    #
    # @return [String] the system architecture type
    #------------------------------------------------------------------------------------------
    def architecture
      `uname -m`.strip
    end

    #------------------------------------------------------------------------------------------
    # Determines the path that the agent will be found in, based on system architecture type.
    #
    # @return [String] agent path
    #------------------------------------------------------------------------------------------
    def agent_unpack_path
      architecture == 'x86_64' || architecture == 'i686' ? 'linux-x86-64/agent' : 'linux-x86-32/agent'
    end

    #------------------------------------------------------------------------------------------
    # Download the agent library from the repository as specified in the dynatrace configuration.
    #------------------------------------------------------------------------------------------
    def download_and_install_agent(dt_home)
      LibertyBuildpack::Util.download_zip(@version, @uri, 'Dynatrace Agent', dt_home)
    rescue => e
      raise "Unable to download the Dynatrace Agent jar. Ensure that the agent jar at #{@uri} is available and accessible. #{e.message}"
    end

    #------------------------------------------------------------------------------------------
    # Determines if the dynatrace service is included in VCAP_SERVICES based on whether the
    # service entry has valid entries.
    #
    # @return [Boolean] true if the app is bound to a dynatrace service
    #------------------------------------------------------------------------------------------
    def dt_service_exist?
      @services.one_service?(DT_SERVICE_NAME, SERVER_KEY)
    end

    #------------------------------------------------------------------------------------------
    # Retrieves Dynatrace options from the dynatrace service in VCAP_SERVICES.
    #
    # @return [String] options string to be appended to java agent options
    #------------------------------------------------------------------------------------------
    def get_service_options
      begin
        @dt_service = @services.find_service(DT_SERVICE_NAME)
        dt_profile_name = vcap_dt_profile ? vcap_dt_profile : DT_DEFAULT_PROFILE_NAME
        if vcap_dt_server.nil?
          raise 'DynaTrace server is not set, server must be set in service credentials.'
        end
        @dt_options = "name=#{dt_profile_name},server=#{vcap_dt_server}"

        if @dt_service.key?(OPTIONS_KEY) && @dt_service[OPTIONS_KEY].any?
          @dt_service[OPTIONS_KEY].each do |k, v|
            @dt_options << ",#{k}=#{v}"
          end
        end
      rescue => e
        @logger.error("Unable to process the service options for the DynaTrace Agent framework. #{e.message}")
      end

      @dt_options.nil? ? nil : @dt_options
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
        @logger.error("Unable to process the configuration for the DynaTrace Agent framework. #{e.message}")
      end

      @version.nil? ? nil : "dynatrace-agent-#{@version}"
    end

    #-----------------------------------------------------------------------------------------
    # The profile name made available from VCAP_SERVICES for the dynatrace serivce
    #
    # @return [String] the profile name from VCAP_SERVICES
    #------------------------------------------------------------------------------------------
    def vcap_dt_profile
      @services.find_service(DT_SERVICE_NAME)[CREDENTIALS_KEY][PROFILE_KEY]
    end

    #-----------------------------------------------------------------------------------------
    # The server name made available from VCAP_SERVICES for the dynatrace serivce
    #
    # @return [String] the server name from VCAP_SERVICES
    #------------------------------------------------------------------------------------------
    def vcap_dt_server
      @services.find_service(DT_SERVICE_NAME)[CREDENTIALS_KEY][SERVER_KEY]
    end

  end
end

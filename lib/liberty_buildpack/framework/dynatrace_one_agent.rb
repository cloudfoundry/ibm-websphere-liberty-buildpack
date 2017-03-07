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
  # The DynatraceOneAgent class that provides Dynatrace OneAgent resources as a framework to applications
  #------------------------------------------------------------------------------------
  class DynatraceOneAgent

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
    # Determines if the application's VCAP environment and the configured Dynatrace configuration
    # is available for the Dynatrace framework to provide a configured Dynatrace agent. Valid
    # detect is based on VCAP_SERVICES, VCAP_APPLICATION, and the repository root index.yml
    # defined by the Dynatrace configuration.
    #
    # @return [String] the detected versioned ID if the environment and config are valid, otherwise nil
    #------------------------------------------------------------------------------------------
    def detect
      dynatrace_service_exist? ? process_config : nil
    end

    #-----------------------------------------------------------------------------------------
    # Create the dynatrace_one_agent directory and its contents for the app droplet.
    #------------------------------------------------------------------------------------------
    def compile
      if @app_dir.nil?
        raise 'app directory must be provided'
      elsif @version.nil? || @uri.nil?
        raise "Version #{@version} or uri #{@uri} is not available, detect needs to be invoked"
      end

      # create a dynatrace home dir in the droplet
      dynatrace_home = File.join(@app_dir, DYNATRACE_HOME_DIR)
      FileUtils.mkdir_p(dynatrace_home)
      @logger.debug("Dynatrace OneAgent home directory: #{dynatrace_home}")

      download_and_install_agent(dynatrace_home)

      # export dynatrace specific environment variables
      export_dynatrace_app_environment_variables
      export_dynatrace_connection_environment_variables
    end

    #-----------------------------------------------------------------------------------------
    # Create the Dynatrace agent options appended as java_opts.
    #------------------------------------------------------------------------------------------
    def release
      # dynatrace paths within the droplet
      pwd = ENV['PWD']
      dynatrace_home_dir = "#{pwd}/app/#{DYNATRACE_HOME_DIR}"
      dynatrace_one_agent = File.join(dynatrace_home_dir, 'agent', lib_name, 'liboneagentloader.so')
      dynatrace_one_agent = File.join(dynatrace_home_dir, 'agent', lib_name, 'libruxitagentloader.so') unless File.file?(File.join(@app_dir, DYNATRACE_HOME_DIR, 'agent', lib_name, 'liboneagentloader.so'))

      @logger.debug("dynatrace_one_agent: #{dynatrace_one_agent}")

      # create the dynatrace agent command as java_opts
      @java_opts << "-agentpath:#{dynatrace_one_agent}"
    end

    private

    # Name of the dynatrace service
    DYNATRACE_SERVICE_NAME = /ruxit|dynatrace/

    # VCAP_SERVICES keys
    CREDENTIALS_KEY = 'credentials'.freeze
    SERVER = 'server'.freeze
    TENANT = 'tenant'.freeze
    TENANTTOKEN = 'tenanttoken'.freeze
    APITOKEN = 'apitoken'.freeze
    APIURL = 'apiurl'.freeze
    ENVIRONMENTID = 'environmentid'.freeze
    ENDPOINT = 'endpoint'.freeze

    # dynatrace's directory of artifacts in the droplet
    DYNATRACE_HOME_DIR = '.dynatrace_one_agent'.freeze

    # dynatrace ENV variables
    RUXIT_APPLICATION_ID = 'RUXIT_APPLICATIONID'.freeze
    RUXIT_HOST_ID = 'RUXIT_HOST_ID'.freeze
    DT_TENANT = 'DT_TENANT'.freeze
    DT_TENANTTOKEN = 'DT_TENANTTOKEN'.freeze
    DT_CONNECTION_POINT = 'DT_CONNECTION_POINT'.freeze

    #------------------------------------------------------------------------------------------
    # Determines the system architecture.
    #
    # @return [String] the system architecture type
    #------------------------------------------------------------------------------------------
    def architecture
      `uname -m`.strip
    end

    #------------------------------------------------------------------------------------------
    # Download the agent library from the repository as specified in the dynatrace configuration.
    #------------------------------------------------------------------------------------------
    def download_and_install_agent(dynatrace_home)
      LibertyBuildpack::Util.download_zip(@version, @uri, 'Dynatrace OneAgent', dynatrace_home)
    rescue => e
      raise "Unable to download the Dynatrace OneAgent. Ensure that the agent at #{@uri} is available and accessible. #{e.message}"
    end

    #------------------------------------------------------------------------------------------
    # Determines if the dynatrace service is included in VCAP_SERVICES based on whether the
    # service entry has valid entries.
    #
    # @return [Boolean] true if the app is bound to a dynatrace service
    #------------------------------------------------------------------------------------------
    def dynatrace_service_exist?
      @services.one_service? DYNATRACE_SERVICE_NAME, [ENVIRONMENTID, TENANT], [APITOKEN, TENANTTOKEN]
    end

    def supports_apitoken?
      credentials = @services.find_service(DYNATRACE_SERVICE_NAME)[CREDENTIALS_KEY]
      credentials[APITOKEN] ? true : false
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
    # dynatrace oneagent zzip in the repository root or bypasses the repository to directly download_uri
    # the agent from the cluster. If the configuration can be processed and the
    # uri contains a valid dynatrace oneagent zip name, the versioned ID is returned and configuration
    # data is initialized.
    #
    # @return [String] the dynatrace version ID
    #------------------------------------------------------------------------------------------
    def process_config
      begin
        @version, @uri = supports_apitoken? ? agent_download_url : LibertyBuildpack::Repository::ConfiguredItem.find_item(@configuration)
      rescue => e
        @logger.error("Unable to process the configuration for the Dynatrace OneAgent framework. #{e.message}")
      end

      @version.nil? ? nil : "dynatrace-one-agent-#{@version}"
    end

    # Create .profile.d/0dynatrace-app-env.sh with the dynatrace app environment variables
    #
    # @return [void]
    def export_dynatrace_app_environment_variables
      profiled_dir = File.join(@app_dir, '.profile.d')
      FileUtils.mkdir_p(profiled_dir)

      variables = {}
      variables[RUXIT_APPLICATION_ID] = application_id
      variables[RUXIT_HOST_ID] = host_id

      env_file_name = File.join(profiled_dir, '0dynatrace-app-env.sh')
      env_file = File.new(env_file_name, 'w')
      variables.each do |key, value|
        env_file.puts("export #{key}=\"${#{key}:-#{value}}\"") # "${VAR1:-default value}"
      end
      env_file.close
    end

    # Create .profile.d/dynatrace-env.sh with the dynatrace agent connection environment variables
    #
    # @return [void]
    def export_dynatrace_connection_environment_variables
      profiled_dir = File.join(@app_dir, '.profile.d')
      FileUtils.mkdir_p(profiled_dir)

      if supports_apitoken? && File.file?(File.join(@app_dir, DYNATRACE_HOME_DIR, 'dynatrace-env.sh'))
        # copy dynatrace-env.sh from agent zip to .profile.d for setting DT_CONNECTION_POINT etc
        dynatrace_env_sh = File.join(@app_dir, DYNATRACE_HOME_DIR, 'dynatrace-env.sh')
        FileUtils.cp(dynatrace_env_sh, profiled_dir)
      else
        credentials = @services.find_service(DYNATRACE_SERVICE_NAME)[CREDENTIALS_KEY]
        variables = {}
        variables[DT_TENANT] = tenant(credentials)
        variables[DT_TENANTTOKEN] = tenanttoken(credentials)
        variables[DT_CONNECTION_POINT] = server(credentials)

        env_file_name = File.join(profiled_dir, 'dynatrace-env.sh')
        env_file = File.new(env_file_name, 'w')
        variables.each do |key, value|
          env_file.puts("export #{key}=\"${#{key}:-#{value}}\"") # "${VAR1:-default value}"
        end
        env_file.close
      end
    end

    def agent_download_url
      credentials = @services.find_service(DYNATRACE_SERVICE_NAME)[CREDENTIALS_KEY]
      download_uri = "#{api_base_url}/v1/deployment/installer/agent/unix/paas/latest?include=java&bitness=64&"
      download_uri += "Api-Token=#{credentials[APITOKEN]}"
      ['latest', download_uri]
    end

    def api_base_url
      credentials = @services.find_service(DYNATRACE_SERVICE_NAME)[CREDENTIALS_KEY]
      return credentials[APIURL] unless credentials[APIURL].nil?
      base_url = credentials[ENDPOINT] || credentials[SERVER] || "https://#{tenant(credentials)}.live.dynatrace.com"
      base_url = base_url.gsub('/communication', '').concat('/api').gsub(':8443', '').gsub(':443', '')
      base_url
    end

    def application_id
      @vcap_application['application_name']
    end

    def host_id
      "#{@vcap_application['application_name']}_${CF_INSTANCE_INDEX}"
    end

    def server(credentials)
      given_endp = credentials[ENDPOINT] || credentials[SERVER] || "https://#{tenant(credentials)}.live.dynatrace.com"
      supports_apitoken? ? server_from_api : given_endp
    end

    def server_from_api
      dynatrace_one_agent_manifest = File.join(@app_dir, DYNATRACE_HOME_DIR, 'manifest.json')
      @logger.debug { "File exists?: #{dynatrace_one_agent_manifest} #{File.file?(dynatrace_one_agent_manifest)}" }
      endpoints = JSON.parse(File.read(dynatrace_one_agent_manifest))['communicationEndpoints']
      endpoints.join(';')
    end

    def tenant(credentials)
      credentials[ENVIRONMENTID] || credentials[TENANT]
    end

    def tenanttoken(credentials)
      supports_apitoken? ? tenanttoken_from_api : credentials[TENANTTOKEN]
    end

    def tenanttoken_from_api
      dynatrace_one_agent_manifest = File.join(@app_dir, DYNATRACE_HOME_DIR, 'manifest.json')
      @logger.debug { "File exists?: #{dynatrace_one_agent_manifest} #{File.file?(dynatrace_one_agent_manifest)}" }
      JSON.parse(File.read(dynatrace_one_agent_manifest))['tenantToken']
    end

  end
end

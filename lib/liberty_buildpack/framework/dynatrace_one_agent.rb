# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2016-2017 the original author or authors.
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
    # detect is based on VCAP_SERVICES.
    #
    # @return [String] the detected versioned ID if the environment and config are valid, otherwise nil
    #------------------------------------------------------------------------------------------
    def detect
      !service.nil? ? process_config : nil
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
      @java_opts << "-agentpath:#{agent_path}"
    end

    private

    # Service filter of the dynatrace service
    FILTER = /dynatrace/

    # VCAP_SERVICES keys
    CREDENTIALS_KEY = 'credentials'.freeze
    APITOKEN = 'apitoken'.freeze
    APIURL = 'apiurl'.freeze
    ENVIRONMENTID = 'environmentid'.freeze

    # dynatrace's directory of artifacts in the droplet
    DYNATRACE_HOME_DIR = '.dynatrace_one_agent'.freeze

    # dynatrace ENV variables
    DT_APPLICATION_ID = 'DT_APPLICATIONID'.freeze
    DT_HOST_ID = 'DT_HOST_ID'.freeze

    #------------------------------------------------------------------------------------------
    # Searches for a single service which name, label or tag contains 'dynatrace' and
    # at least 'environmentid' and 'apitoken' is set as credentials.
    #
    # @return [Hash] the single service matching the criterias
    #------------------------------------------------------------------------------------------
    def service
      candidates = @services.select do |candidate|
        (
          (candidate['label'] == 'user-provided' && candidate['name'] =~ FILTER) ||
          candidate['label'] =~ FILTER ||
          (!candidate['tags'].nil? && candidate['tags'].any? { |tag| tag =~ FILTER })
        ) &&
        !candidate[CREDENTIALS_KEY].nil? &&
        candidate[CREDENTIALS_KEY][ENVIRONMENTID] && candidate[CREDENTIALS_KEY][APITOKEN]
      end

      candidates.one? ? candidates.first : nil
    end

    #------------------------------------------------------------------------------------------
    # Download the agent library from the repository as specified in the dynatrace configuration.
    #------------------------------------------------------------------------------------------
    def download_and_install_agent(dynatrace_home)
      LibertyBuildpack::Util.download_zip(@version, @uri, 'Dynatrace OneAgent', dynatrace_home)
    rescue => e
      raise "Unable to download the Dynatrace OneAgent. Ensure that the agent at #{@uri} is available and accessible. #{e.message}"
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
        @version, @uri = agent_download_url
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
      variables[DT_APPLICATION_ID] = application_id
      variables[DT_HOST_ID] = host_id

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

      # copy dynatrace-env.sh from agent zip to .profile.d for setting DT_CONNECTION_POINT etc
      dynatrace_env_sh = File.join(@app_dir, DYNATRACE_HOME_DIR, 'dynatrace-env.sh')
      FileUtils.cp(dynatrace_env_sh, profiled_dir)
    end

    def agent_path
      manifest = JSON.parse(File.read(File.join(@app_dir, DYNATRACE_HOME_DIR, 'manifest.json')))
      java_binaries = manifest['technologies']['java']['linux-x86-64']
      loader = java_binaries.find { |bin| bin['binarytype'] == 'loader' }
      "#{ENV['PWD']}/app/#{DYNATRACE_HOME_DIR}/#{loader['path']}"
    end

    def agent_download_url
      credentials = service[CREDENTIALS_KEY]
      download_uri = "#{api_base_url}/v1/deployment/installer/agent/unix/paas/latest?include=java&bitness=64&"
      download_uri += "Api-Token=#{credentials[APITOKEN]}"
      ['latest', download_uri]
    end

    def api_base_url
      credentials = service[CREDENTIALS_KEY]
      credentials[APIURL] || "https://#{credentials[ENVIRONMENTID]}.live.dynatrace.com/api"
    end

    def application_id
      @vcap_application['application_name']
    end

    def host_id
      "#{@vcap_application['application_name']}_${CF_INSTANCE_INDEX}"
    end

  end
end

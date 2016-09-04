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

module LibertyBuildpack::Framework

  #------------------------------------------------------------------------------------
  # The NewRelicAgent class that provides New Relic Agent resources as a framework to applications
  #------------------------------------------------------------------------------------
  class NewRelicAgent

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
    # Determines if the application's VCAP environment and the configured new relic configuration
    # is available for the new relic framework to provide a configured newrelic agent. Valid
    # detect is based on VCAP_SERVICES, VCAP_APPLICATION, and the repository root index.yml
    # defined by the new relic configuration.
    #
    # @return [String] the detected versioned ID if the environment and config are valid, otherwise nil
    #------------------------------------------------------------------------------------------
    def detect
      app_has_name? && nr_service_exist? ? process_config : nil
    end

    #-----------------------------------------------------------------------------------------
    # Create the new_relic_agent directory and its contents for the app droplet.
    #------------------------------------------------------------------------------------------
    def compile
      if @app_dir.nil?
        raise 'app directory must be provided'
      elsif @version.nil? || @uri.nil?
        raise "Version #{@version} or uri #{@uri} is not available, detect needs to be invoked"
      end

      # create a new relic home dir in the droplet
      nr_home = File.join(@app_dir, NR_HOME_DIR)
      FileUtils.mkdir_p(nr_home)

      # place new relic resources in newrelic's home dir
      copy_agent_config(nr_home)
      download_agent(@version, @uri, jar_name, nr_home)
    end

    #-----------------------------------------------------------------------------------------
    # Create the newrelic agent options appended as java_opts.
    #------------------------------------------------------------------------------------------
    def release
      # new relic paths within the droplet
      app_dir = @common_paths.relative_location
      nr_home_dir = File.join(app_dir, NR_HOME_DIR)
      nr_agent = File.join(nr_home_dir, jar_name)
      nr_logs_dir = @common_paths.log_directory

      # create the new relic agent command as java_opts
      @java_opts << "-javaagent:#{nr_agent}"
      @java_opts << "-Dnewrelic.home=#{nr_home_dir}"
      @java_opts << "-Dnewrelic.config.license_key=#{vcap_nr_license}"
      @java_opts << "-Dnewrelic.config.app_name=#{vcap_app_name}"
      @java_opts << "-Dnewrelic.config.log_file_path=#{nr_logs_dir}"
    end

    private

    # Name of the new relic service
    NR_SERVICE_NAME = 'newrelic'.freeze

    # VCAP_SERVICES keys
    LICENSE_KEY = 'licenseKey'.freeze
    CREDENTIALS_KEY = 'credentials'.freeze

    # VCAP_APPLICATION keys
    APPLICATION_NAME_KEY = 'application_name'.freeze

    # new relic's directory of artifacts in the droplet
    NR_HOME_DIR = '.new_relic_agent'.freeze

    def jar_name
      "new-relic-#{@version}.jar"
    end

    #-----------------------------------------------------------------------------------------
    # Determines if the New Relic service is included in VCAP_SERVICES based on whether the
    # service entry has valid entries.
    #
    # @return [Boolean]  true if the app is bound to a new relic service
    #------------------------------------------------------------------------------------------
    def nr_service_exist?
      @services.one_service?(NR_SERVICE_NAME, LICENSE_KEY)
    end

    #-----------------------------------------------------------------------------------------
    # Determines if the application name is available from VCAP_APPLICATION.
    #
    # @return [Boolean]  true if the app is bound to a new relic service
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
    # The license information made available from VCAP_SERVICES for the new relic serivce
    #
    # @return [String]  the license information from VCAP_SERVICES
    #------------------------------------------------------------------------------------------
    def vcap_nr_license
      @services.find_service(NR_SERVICE_NAME)[CREDENTIALS_KEY][LICENSE_KEY]
    end

    #-----------------------------------------------------------------------------------------
    # Processes the new relic configuration to obtain the corresponding version and uri of the
    # new relic agent jar in the repository root. If the configuration can be processed and the
    # uri contains a valid new relic agent jar name, the versioned ID is returned and configuration
    # data is initialized.
    #
    # @return [String] the new relic version ID
    #------------------------------------------------------------------------------------------
    def process_config
      begin
        @version, @uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(@configuration)
      rescue => e
        @logger.error("Unable to process the configuration for the New Relic Agent framework. #{e.message}")
      end

      @version.nil? ? nil : "new-relic-#{@version}"
    end

    #-----------------------------------------------------------------------------------------
    # Copies the agent configuration from the buildpack resources directory to the application's droplet.
    #------------------------------------------------------------------------------------------
    def copy_agent_config(target_dir)
      agent_resource = File.join('..', '..', '..', 'resources', 'new_relic_agent').freeze
      agent_resource_path = File.expand_path(agent_resource, File.dirname(__FILE__))
      # only grab the files in the New Relic Agent template
      FileUtils.cp_r(agent_resource_path + '/.', target_dir)
    end

    #-----------------------------------------------------------------------------------------
    # Download the agent library from the repository as specified in the new relic configuration.
    #------------------------------------------------------------------------------------------
    def download_agent(version_desc, uri_source, target_jar_name, target_dir)
      LibertyBuildpack::Util.download(version_desc, uri_source, 'New Relic Agent', target_jar_name, target_dir)
    rescue => e
      raise "Unable to download the New Relic Agent jar. Ensure that the agent jar at #{uri_source} is available and accessible. #{e.message}"
    end
  end
end

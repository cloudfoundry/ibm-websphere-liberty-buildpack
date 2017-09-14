# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2017 the original author or authors.
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
require 'fileutils'
require 'rexml/document'

module LibertyBuildpack::Framework

  #------------------------------------------------------------------------------------
  # The ContrastSecurityAgent class that provides Contrast Security Agent resources as a framework to applications
  #------------------------------------------------------------------------------------
  class ContrastSecurityAgent

    #-----------------------------------------------------------------------------------------
    # Creates an instance, passing in a context of information available to the component
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Hash] :configuration the properties provided by the user
    # @option context [CommonPaths] :common_paths the set of paths common across components that components should reference`
    # @option context [Hash] :vcap_services the services bound to the application provided by cf
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    #-----------------------------------------------------------------------------------------
    def initialize(context = {})
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @vcap_application = context[:vcap_application]
      @configuration = context[:configuration]
      @common_paths = context[:common_paths] || LibertyBuildpack::Container::CommonPaths.new
      @vcap_services = context[:vcap_services]
      @services = @vcap_services ? LibertyBuildpack::Services::VcapServices.new(@vcap_services) : LibertyBuildpack::Services::VcapServices.new({})
      @java_opts = context[:java_opts]
    end

    #-----------------------------------------------------------------------------------------
    # Determines if the application's VCAP environment and the configured contrast security configuration
    # is available for the contrast security framework to provide a configured contrast security agent. Valid
    # detect is based on VCAP_SERVICES, VCAP_APPLICATION, and the repository root index.yml
    # defined by the contrast security configuration.
    #
    # @return [String] the detected versioned ID if the environment and config are valid, otherwise nil
    #------------------------------------------------------------------------------------------
    def detect
      contrast_service_exist? ? process_config : nil
    end

    #-----------------------------------------------------------------------------------------
    # Create the contrast directory and its contents for the app droplet.
    #------------------------------------------------------------------------------------------
    def compile
      if @app_dir.nil?
        raise 'app directory must be provided' if @app_dir.nil?
      elsif @version.nil? || @uri.nil?
        raise "Version #{@version} or uri #{@uri} is not available, detect needs to be invoked"
      end

      # create a contrast home dir in the droplet
      contrast_home = File.join(@app_dir, CONTRAST_DIR)
      FileUtils.mkdir_p(contrast_home)

      write_configuration(find_service['credentials'])
      download_agent(@version, @uri, jar_name, contrast_home)
    end

    #-----------------------------------------------------------------------------------------
    # Processes the contrast security configuration to obtain the corresponding version and uri of the
    # contrast security agent jar in the repository root. If the configuration can be processed and the
    # uri contains a valid contrast security agent jar name, the versioned ID is returned and configuration
    # data is initialized.
    #
    # @return [String] the contrast security version ID
    #------------------------------------------------------------------------------------------
    def process_config
      begin
        @version, @uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(@configuration)
      rescue => e
        @logger.error("Unable to process the configuration for the Contrast Security Agent framework. #{e.message}")
      end

      @version.nil? ? nil : version_identifier
    end

    #-----------------------------------------------------------------------------------------
    # Create the contrast security agent options appended as java_opts.
    #------------------------------------------------------------------------------------------
    def release
      # Contrast paths within the droplet
      app_dir = @common_paths.relative_location
      contrast_home_dir = File.join(app_dir, CONTRAST_DIR)
      contrast_agent = File.join(contrast_home_dir, jar_name)
      contrast_config = File.join(contrast_home_dir, CONTRAST_CONFIG_NAME)

      # specify contrast java options
      @java_opts << "-javaagent:#{contrast_agent}=#{contrast_config}"
      @java_opts << "-Dcontrast.dir=#{contrast_home_dir}"
      @java_opts << "-Dcontrast.override.appname=#{vcap_app_name}"
    end

    private

    API_KEY = 'api_key'.freeze
    CONTRAST_CONFIG_NAME = 'contrast.config'.freeze
    CONTRAST_DIR = '.contrast'.freeze
    CONTRAST_FILTER = 'contrast-security'.freeze
    JAVA_AGENT_VERSION = LibertyBuildpack::Util::TokenizedVersion.new('3.4.3').freeze
    PLUGIN_PACKAGE = 'com.aspectsecurity.contrast.runtime.agent.plugins'.freeze
    REFERRAL_TILE = 'contrast_referral_tile'.freeze
    SERVICE_KEY = 'service_key'.freeze
    TEAMSERVER_URL = 'teamserver_url'.freeze
    USERNAME = 'username'.freeze

    def jar_name
      "#{version_identifier}.jar"
    end

    def version_identifier
      if @version < JAVA_AGENT_VERSION
        "contrast-engine-#{@version.to_s.split('_')[0]}"
      else
        "java-agent-#{@version.to_s.split('_')[0]}"
      end
    end

    #-----------------------------------------------------------------------------------------
    # Determines if the Contrast Security service is included in VCAP_SERVICES
    #
    # @return [Boolean]  true if the app is bound to a contrast-security service
    #------------------------------------------------------------------------------------------
    def contrast_service_exist?
      @services.one_service?(CONTRAST_FILTER, TEAMSERVER_URL, USERNAME, API_KEY, SERVICE_KEY) || !referral_tile.nil?
    end

    def add_contrast(doc, credentials)
      contrast = doc.add_element('contrast')
      (contrast.add_element 'id').add_text('default')
      (contrast.add_element 'global-key').add_text(credentials[API_KEY])
      (contrast.add_element 'url').add_text("#{credentials[TEAMSERVER_URL]}/Contrast/s/")
      (contrast.add_element 'results-mode').add_text('never')

      add_user contrast, credentials
      add_plugins contrast
    end

    def add_plugins(contrast)
      plugin_group = contrast.add_element('plugins')

      (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.security.SecurityPlugin")
      (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.architecture.ArchitecturePlugin")
      (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.appupdater.ApplicationUpdatePlugin")
      (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.sitemap.SitemapPlugin")
      (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.frameworks.FrameworkSupportPlugin")
      (plugin_group.add_element 'plugin').add_text("#{PLUGIN_PACKAGE}.http.HttpPlugin")
    end

    def add_user(contrast, credentials)
      user = contrast.add_element('user')
      (user.add_element 'id').add_text(credentials[USERNAME])
      (user.add_element 'key').add_text(credentials[SERVICE_KEY])
    end

    def contrast_config
      File.join(@app_dir, CONTRAST_DIR, CONTRAST_CONFIG_NAME)
    end

    def write_configuration(credentials)
      doc = REXML::Document.new

      add_contrast doc, credentials

      File.open(contrast_config, 'w+') { |f| f.write(doc) }
    end

    #-----------------------------------------------------------------------------------------
    # Download the agent library from the repository as specified in the contrast security configuration.
    #------------------------------------------------------------------------------------------
    def download_agent(version_desc, uri_source, target_jar_name, target_dir)
      LibertyBuildpack::Util.download(version_desc, uri_source, 'Contrast Security Agent', target_jar_name, target_dir)
    rescue => e
      raise "Unable to download the Contrast Security Agent jar. Ensure that the agent jar at #{uri_source} is available and accessible. #{e.message}"
    end

    #-----------------------------------------------------------------------------------------
    # The application name that's made available from VCAP_APPLICATION.
    #
    # @return [String] the application name from VCAP_APPLICATION
    #------------------------------------------------------------------------------------------
    def vcap_app_name
      @vcap_application['application_name']
    end

    def referral_tile
      @services.find do |service|
        unless service['credentials'].nil?
          service['credentials'].key?(REFERRAL_TILE)
        end
      end
    end

    def find_service
      if @services.one_service?(CONTRAST_FILTER, TEAMSERVER_URL, USERNAME, API_KEY, SERVICE_KEY)
        @services.find_service(CONTRAST_FILTER)
      else
        referral_tile
      end
    end

  end
end

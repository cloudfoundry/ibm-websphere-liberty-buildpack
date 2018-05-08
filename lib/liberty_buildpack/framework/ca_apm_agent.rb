# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2018 the original author or authors.
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

require 'fileutils'
require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/framework'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/download'
require 'liberty_buildpack/container/common_paths'
require 'liberty_buildpack/services/vcap_services'

module LibertyBuildpack::Framework

  # The CAAPMAgent class that provides CA APM Agent resource as a framework to applications
  class CAAPMAgent

    # The name of the directory which contains the CA APM agent.
    CA_APM_HOME_DIR = '.ca_apm'.freeze

    # Creates an instance of the CAAPMAgent class and takes as an argument the context hash.
    # @param [Hash] context the context that is provided to the instance, defaults to empty.
    # @option context [String] :app_dir the directory that the application exists in.
    # @option context [Hash] :configuration the properties provided by the user.
    # @option context [CommonPaths] :common_paths the set of paths common across components that components should reference.
    # @option context [Hash] :vcap_application the application information provided by cf.
    # @option context [Hash] :vcap_services the services bound to the application provided by cf.
    # @option context [Array<String>] :java_opts an array in which the java options can be added.
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

    # Determines if the application's VCAP environment and the configured CA APM configuration
    # is available for the CA APM framework to provide a configured CA APM agent. Valid
    # detection is based on VCAP_SERVICES, VCAP_APPLICATION, and the repository root index.yml
    # defined in the CA APM configuration file.
    #
    # @return [String] the detected versioned ID if the environment and config are valid, nil otherwise.
    def detect
      app_has_name? && service_exists? ? process_config : nil
    end

    # Create the ca_apm directory and its contents for the app droplet.
    def compile
      if @app_dir.nil?
        raise 'app directory must be provided'
      elsif @version.nil? || @uri.nil?
        raise "Version #{@version}, uri #{@uri} is not available, detect needs to be invoked"
      end

      ca_apm_home = File.join(@app_dir, CA_APM_HOME_DIR)
      FileUtils.mkdir_p(ca_apm_home)
      download_and_install_agent(ca_apm_home)
    end

    # Appends the CA APM agent to the java options and specified additional properties for the agent.
    def release
      app_dir = @common_paths.relative_location
      ca_apm_home_dir = File.join(app_dir, CA_APM_HOME_DIR)
      ca_apm_agent = File.join(ca_apm_home_dir, 'wily/AgentNoRedefNoRetrans.jar')

      @java_opts << "-javaagent:#{ca_apm_agent}"
      @java_opts << '-Dorg.osgi.framework.bootdelegation=com.wily.*'
      @java_opts << "-Dcom.wily.introscope.agentProfile=#{ca_apm_home_dir}/wily/core/config/IntroscopeAgent.NoRedef.profile"
      credentials = @services.find_service(FILTER)['credentials']

      agent_host_name @java_opts
      agent_name @java_opts, credentials
      add_url @java_opts, credentials
      agent_manager_credential @java_opts, credentials

      @java_opts
    end

    private

    # Name of the CA APM service
    FILTER = /introscope/

    # Checks to see whether the service exists based on the agent_manager_url.
    def service_exists?
      @services.one_service?(FILTER, 'agent_manager_url')
    end

    def app_has_name?
      !@vcap_application.nil? && !vcap_app_name.nil? && !vcap_app_name.empty?
    end

    def vcap_app_name
      @vcap_application['application_name']
    end

    def process_config
      begin
        @version, @uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(@configuration)
      rescue => e
        @logger.error("Unable to process the configuration for the CA APM Agent framework. #{e.message}")
      end

      @version.nil? ? nil : "introscope-agent-#{@version}"
    end

    def add_url(java_opts, credentials)
      agent_manager = agent_manager_url(credentials)

      host, port, socket_factory = parse_url(agent_manager)
      java_opts << "-DagentManager.url.1=#{agent_manager}"
      java_opts << "-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=#{host}"
      java_opts << "-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=#{port}"
      java_opts << "-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=#{socket_factory}"
    end

    # Parse the agent manager url, split first by '://', and then with ':'
    # components is of the format [host, port, socket_factory]
    def parse_url(url)
      components = url.split('://')
      components.unshift('') if components.length == 1
      components[1] = components[1].split(':')
      components.flatten!
      components.push(protocol_mapping(components[0]))
      components.shift
      components
    end

    def protocol_mapping(protocol)
      socket_factory_base = 'com.wily.isengard.postofficehub.link.net.'

      protocol_socket_factory = {
        ''      => socket_factory_base + 'DefaultSocketFactory',
        'ssl'   => socket_factory_base + 'SSLSocketFactory',
        'http'  => socket_factory_base + 'HttpTunnelingSocketFactory',
        'https' => socket_factory_base + 'HttpsTunnelingSocketFactory'
      }

      protocol_socket_factory[protocol] || protocol
    end

    def agent_host_name(java_opts)
      java_opts << "-Dintroscope.agent.hostName=#{@vcap_application['application_uris'][0]}"
    end

    def agent_name(java_opts, credentials)
      name = credentials['agent_name'] || vcap_app_name
      java_opts << "-Dintroscope.agent.agentName=#{name}"
    end

    def agent_manager_url(credentials)
      credentials['agent_manager_url']
    end

    def agent_manager_credential(java_opts, credentials)
      credential = credentials['agent_manager_credential']
      java_opts << "-DagentManager.credential=#{credential}" if credential
    end

    def download_and_install_agent(home)
      LibertyBuildpack::Util.download_tar(@version, @uri, 'CA APM Agent', home)
    rescue => error
      raise "Unable to download the CA APM Agent artifact. Ensure that the agent artifact at #{@uri} is available and accessible. #{error.message}"
    end
  end
end

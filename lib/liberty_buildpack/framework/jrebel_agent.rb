# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
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
require 'liberty_buildpack/container/container_utils'

module LibertyBuildpack::Framework

  # Provides the required detect/compile/release functionality in order to use JRebel with an application
  class JRebelAgent

    # JRebel home directory
    JR_HOME_DIR = '.jrebel'.freeze
    # Name of the main jar file
    JREBEL_JAR = 'jrebel.jar'
    # Directory name
    JREBEL = 'jrebel'
    # Path tho the native agent within the nosetup.zip
    LIBJREBEL_SO = File.join(JREBEL, 'lib', 'libjrebel64.so')

    # Creates an instance, passing in a context of information available to the component
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Hash] :configuration the properties provided by the user
    # @option context [CommonPaths] :common_paths the set of paths common across components that components should reference
    # @option context [Hash] :vcap_application the application information provided by cf
    # @option context [Hash] :vcap_services the services bound to the application provided by cf
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    def initialize(context = {})
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @configuration = context[:configuration]
      @common_paths = context[:common_paths] || LibertyBuildpack::Container::CommonPaths.new
      @java_opts = context[:java_opts]
    end

    #-----------------------------------------------------------------------------------------
    # Determines if the application contains a rebel-remote.xml to provide a configured jrebel agent
    #
    # @return [String] the detected versioned ID if the environment and config are valid, otherwise nil
    #------------------------------------------------------------------------------------------
    def detect
      if File.exists?("#{@app_dir}/WEB-INF/classes/rebel-remote.xml")
        @logger.info('Found rebel-remote.xml, enabling JRebel')
        @version, @uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(@configuration)
        @nosetup_zip = "jrebel-#{@version}-nosetup.zip"
        "jrebel-#{@version}"
      else
        @logger.debug('No rebel-remote.xml found in the application.')
        nil
      end
    end

    #-----------------------------------------------------------------------------------------
    # Create the JRebel directory and its contents for the app droplet.
    #------------------------------------------------------------------------------------------
    def compile
      if @app_dir.nil?
        raise 'app directory must be provided'
      elsif @version.nil? || @uri.nil? || @nosetup_zip.nil?
        raise "Version #{@version}, uri #{@uri}, or new jrebel-nosetup.zip #{@nosetup_zip} is not available, detect needs to be invoked"
      end

      jr_home = File.join(@app_dir, JR_HOME_DIR)
      FileUtils.mkdir_p(jr_home)

      download_nosetup_zip(jr_home)
      FileUtils.rm_r(File.join(jr_home, JREBEL)) if File.exist?(File.join(jr_home, JREBEL))
      LibertyBuildpack::Container::ContainerUtils.unzip(File.join(jr_home, @nosetup_zip), jr_home)
    end

    #-----------------------------------------------------------------------------------------
    # Download the JRebel zip from the repository as specified in the JRebel configuration.
    #------------------------------------------------------------------------------------------
    def download_nosetup_zip(jr_home)
      LibertyBuildpack::Util.download(@version, @uri, 'JRebel zip', @nosetup_zip, jr_home)
    rescue => e
      raise "Unable to download the JRebel zip. Ensure that the zip at #{@uri} is available and accessible. #{e.message}"
    end

    #-----------------------------------------------------------------------------------------
    # Create the JRebel agent options appended as java_opts.
    #------------------------------------------------------------------------------------------
    def release
      app_dir = @common_paths.relative_location

      jr_home = File.join(app_dir, JR_HOME_DIR)
      jr_native_agent = File.join(jr_home, LIBJREBEL_SO)

      jr_log = File.join(@common_paths.log_directory, 'jrebel.log')

      @java_opts << "-agentpath:#{jr_native_agent}"
      @java_opts << '-Xshareclasses:none'
      @java_opts << '-Drebel.remoting_plugin=true'
      @java_opts << '-Drebel.redefine_class=false'
      @java_opts << '-Drebel.log=true'
      @java_opts << "-Drebel.log.file=#{jr_log}"
    end
  end
end

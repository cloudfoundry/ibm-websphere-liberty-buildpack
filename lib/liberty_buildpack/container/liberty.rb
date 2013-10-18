# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013 the original author or authors.
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
require 'liberty_buildpack/container'
require 'liberty_buildpack/container/container_utils'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/application_cache'
require 'liberty_buildpack/util/format_duration'
require 'open-uri'

module LibertyBuildpack::Container
  # Encapsulates the detect, compile, and release functionality for Liberty applications.
  class Liberty
    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [String] :lib_directory the directory that additional libraries are placed in
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
      @lib_directory = context[:lib_directory]
      @configuration = context[:configuration]
      @liberty_version, @liberty_uri, @liberty_license = Liberty.find_liberty(@app_dir, @configuration)
      @vcap_services = context[:vcap_services]
      @vcap_application = context[:vcap_application]
    end

    # Get a list of web applications that are in the server directory
    #
    # @return [Array<String>] :array of file names of discovered applications
    def apps
      apps_found = []
      server_xml = Liberty.server_xml(@app_dir)
      if Liberty.web_inf(@app_dir)
        apps_found = [@app_dir]
      elsif server_xml
        apps_found = Dir.glob(File.expand_path(File.join(server_xml, '..', '**', '*.war')))
        Liberty.expand_apps(apps_found)
      end
      apps_found
    end

    # Detects whether this application is a Liberty application.
    #
    # @return [String] returns +liberty-<version>+ if and only if the application has a server.xml, otherwise
    #                  returns +nil+
    def detect
      @liberty_version ? [liberty_id(@liberty_version)] : nil
    end

    # Downloads and unpacks a Liberty instance
    #
    # @return [void]
    def compile(license_ids)
      liberty_license = open(@liberty_license).read
      download_liberty
      update_server_xml
      link_application
      link_libs
      make_server_script_runnable
      set_liberty_system_properties
    end

    # Creates the command to run the Liberty application.
    #
    # @return [String] the command to run the application.
    def release
      create_vars_string = File.join(LIBERTY_HOME, 'create_vars.rb') << ' .liberty/usr/servers/' << server_name << '/runtime-vars.xml && '
      java_home_string = "JAVA_HOME=\"$PWD/#{@java_home}\""
      java_opts_string = ContainerUtils.space(ContainerUtils.to_java_opts_s(@java_opts))
      java_opts_string = ContainerUtils.space("JVM_ARGS=\"#{java_opts_string}\"")
      start_script_string = ContainerUtils.space(File.join(LIBERTY_HOME, 'bin', 'server'))
      start_script_string << ContainerUtils.space('run')
      server_name_string = ContainerUtils.space(server_name)
      "#{create_vars_string}#{java_home_string}#{java_opts_string}#{start_script_string}#{server_name_string}"
    end

    private

    def set_liberty_system_properties
      resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
      create_vars_destination = File.join(liberty_home, 'create_vars.rb')
      FileUtils.cp(File.join(resources, 'create_vars.rb'), create_vars_destination)

      system("chmod +x #{create_vars_destination}")
    end

    KEY_HTTP_PORT = 'port'.freeze

    RESOURCES = File.join('..', '..', '..', 'resources', 'liberty').freeze

    KEY_SUPPORT = 'support'.freeze

    LIBERTY_HOME = '.liberty'.freeze

    USR_PATH = 'usr'.freeze

    SERVER_XML_GLOB = 'wlp/usr/servers/*/server.xml'.freeze

    SERVER_XML = 'server.xml'.freeze

    WEB_INF = 'WEB-INF'.freeze

    def update_server_xml
      server_xml = Liberty.server_xml(@app_dir)
      if server_xml
        server_xml_doc = File.open(server_xml, 'r') { |file| REXML::Document.new(file) }
        server_xml_doc.context[:attribute_quote] = :quote

        endpoints = REXML::XPath.match(server_xml_doc, '/server/httpEndpoint')

        if endpoints.empty?
          endpoint = REXML::Element.new('httpEndpoint', server_xml_doc.root)
        else
          endpoint = endpoints[0]
          endpoints.drop(1).each { |element| element.parent.delete_element(element) }
        end
        endpoint.add_attribute('host', '*')
        endpoint.add_attribute('httpPort', "${#{KEY_HTTP_PORT}}")
        endpoint.delete_attribute('httpsPort')

        include_file = REXML::Element.new('include', server_xml_doc.root)
        include_file.add_attribute('location', 'runtime-vars.xml')

        File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
      elsif Liberty.web_inf(@app_dir)
        FileUtils.mkdir_p(File.join(@app_dir, '.liberty', 'usr', 'servers', 'defaultServer'))
        resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
        FileUtils.cp(File.join(resources, 'server.xml'), default_server_path)
      else
        raise 'Neither a server.xml or WEB-INF directory was found.'
      end
    end

    def make_server_script_runnable
      server_script = File.join liberty_home, 'bin', 'server'
      system "chmod +x #{server_script}"
    end

    def server_name
      if Liberty.liberty_directory @app_dir
        candidates = Dir[File.join(@app_dir, 'wlp', 'usr', 'servers', '*')]
        raise "Incorrect number of servers to deploy (expecting exactly one): #{candidates}" if candidates.size != 1
        File.basename(candidates[0])
      elsif Liberty.server_directory @app_dir
        return 'defaultServer'
      elsif Liberty.web_inf @app_dir
        return 'defaultServer'
      else
        raise 'Could not find either a WEB-INF directory or a server.xml.'
      end
    end

    def download_liberty
      download_start_time = Time.now
      print "-----> Downloading Liberty #{@liberty_version} from #{@liberty_uri}"
      LibertyBuildpack::Util::ApplicationCache.new.get(@liberty_uri) do |file| # TODO: Use global cache
        puts "(#{(Time.now - download_start_time).duration})"
        expand(file, @configuration)
      end
    end

    def expand(file, configuration)
      expand_start_time = Time.now
      print "       Expanding Liberty to #{LIBERTY_HOME} "

      Dir.mktmpdir do |root|
        FileUtils.rm_rf(liberty_home)
        FileUtils.mkdir_p(liberty_home)
        system "unzip -qq #{file.path} -d #{root} 2>&1"
        system "mv #{root}/wlp/* #{liberty_home}/"
      end

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_liberty(app_dir, configuration)
      if server_xml(app_dir)
        version, uri, license = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration) do |candidate_version|
          fail "Malformed Liberty version #{candidate_version}: too many version components" if candidate_version[4]
        end
      elsif web_inf(app_dir)
        version, uri, license = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration) do |candidate_version|
          fail "Malformed Liberty version #{candidate_version}: too many version components" if candidate_version[4]
        end
      else
        version = nil
        uri = nil
        license = nil
      end

      return version, uri, license
    rescue => e
      raise RuntimeError, "Liberty container error: #{e.message}", e.backtrace
    end

    def liberty_id(version)
      "liberty-#{version}"
    end

    def link_application
      if Liberty.liberty_directory(@app_dir)
        FileUtils.rm_rf(usr)
        FileUtils.mkdir_p(liberty_home)
        FileUtils.ln_sf(Pathname.new(File.join(@app_dir, 'wlp', 'usr')).relative_path_from(Pathname.new(liberty_home)), liberty_home)
      elsif Liberty.server_directory(@app_dir)
        FileUtils.rm_rf(default_server_path)
        FileUtils.mkdir_p(default_server_path)
        default_server_pathname = Pathname.new(default_server_path)
        Pathname.glob(File.join(@app_dir, '*')) do |file|
          FileUtils.ln_sf(file.relative_path_from(default_server_pathname), default_server_path)
        end
      end
    end

    def link_libs
      apps.each do |app_dir|
        libs = ContainerUtils.libs(app_dir, @lib_directory)

        if libs
          app_web_inf_lib = Liberty.web_inf_lib(app_dir)
          FileUtils.mkdir_p(app_web_inf_lib) unless File.exists?(app_web_inf_lib)
          app_web_inf_lib_path = Pathname.new(app_web_inf_lib)
          Pathname.glob(File.join(@lib_directory, '*.jar')) do |jar|
            FileUtils.ln_sf(jar.relative_path_from(app_web_inf_lib_path), app_web_inf_lib)
          end
        end
      end
    end

    def myapp_dir
      File.join(apps_dir, 'myapp')
    end

    def apps_dir
      File.join(default_server_path, 'apps')
    end

    def servers_directory
      File.join(liberty_home, 'usr', 'servers')
    end

    def default_server_path
      File.join(servers_directory, 'defaultServer')
    end

    def usr
      File.join(liberty_home, USR_PATH)
    end

    def liberty_home
      File.join(@app_dir, LIBERTY_HOME)
    end

    def self.web_inf_lib(app_dir)
      File.join app_dir, 'WEB-INF', 'lib'
    end

    def self.web_inf(app_dir)
      web_inf = File.join(app_dir, WEB_INF)
      File.directory?(File.join(app_dir, WEB_INF)) ? web_inf : nil
    end

    def self.server_directory(server_dir)
      server_xml = File.join(server_dir, SERVER_XML)
      File.file? server_xml ? server_xml : nil
    end

    def self.liberty_directory(app_dir)
      candidates = Dir[File.join(app_dir, SERVER_XML_GLOB)]
      if candidates.size > 1
        raise "Incorrect number of servers to deploy (expecting exactly one): #{candidates}"
      end
      candidates.any? ? candidates[0] : nil
    end

    def self.server_xml(app_dir)
      deep_candidates = Dir[File.join(app_dir, SERVER_XML_GLOB)]
      shallow_candidates = Dir[File.join(app_dir, SERVER_XML)]
      candidates = deep_candidates.concat shallow_candidates
      if candidates.size > 1
        raise "Incorrect number of servers to deploy (expecting exactly one): #{candidates}"
      end
      candidates.any? ? candidates[0] : nil
    end

    def self.expand_apps(apps)
      apps.each do |app|
        if File.file? app
          temp_directory = "#{app}.tmp"
          system("unzip -oxq '#{app}' -d '#{temp_directory}'")
          File.delete(app)
          File.rename(temp_directory, app)
        end
      end
    end

  end

end

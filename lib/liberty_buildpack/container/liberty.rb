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
require 'liberty_buildpack/util/license_management'
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
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      prep_app(@app_dir)
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
      @lib_directory = context[:lib_directory]
      @configuration = context[:configuration]
      @liberty_version, @liberty_uri, @liberty_license = Liberty.find_liberty(@app_dir, @configuration)
      @vcap_services = context[:vcap_services]
      @vcap_application = context[:vcap_application]
      @license_id = context[:license_ids]['IBM_LIBERTY_LICENSE']
      @environment = context[:environment]
      @apps = apps
    end

    # Extracts archives that are pushed initially
    def prep_app(app_dir)
      ['*.zip', '*.ear'].each do |archive|
        app = Liberty.contains_type(app_dir, archive)
        Liberty.splat_expand(app) if app
      end
    end

    # Get a list of web applications that are in the server directory
    #
    # @return [Array<String>] :array of file names of discovered applications
    def apps
      apps_found = []
      server_xml = Liberty.server_xml(@app_dir)
      if Liberty.web_inf(@app_dir)
        apps_found = [@app_dir]
      elsif Liberty.meta_inf(@app_dir)
        apps_found = [@app_dir]
        wars = Dir.glob(File.expand_path(File.join(@app_dir, '*.war')))
        Liberty.expand_apps(wars)
      elsif server_xml
        ['*.war', '*.ear'].each { |suffix| apps_found += Dir.glob(File.expand_path(File.join(server_xml, '..', '**', suffix))) }
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
    def compile
      unless LibertyBuildpack::Util.check_license(@liberty_license, @license_id)
        print "\nYou have not accepted the IBM Liberty License.\n\nVisit the following uri:\n#{@liberty_license}\n\nExtract the license number (D/N:) and place it inside your manifest file as a ENV property e.g. \nENV: \n  IBM_LIBERTY_LICENSE: {License Number}.\n"
        raise
      end

      download_liberty
      update_server_xml
      link_application
      make_server_script_runnable
      # Need to do minify here to have server_xml updated and applications and libs linked.
      minify_liberty if minify?
      set_liberty_system_properties
    end

    # Creates the command to run the Liberty application.
    #
    # @return [String] the command to run the application.
    def release
      create_vars_string = File.join(LIBERTY_HOME, 'create_vars.rb') << ' .liberty/usr/servers/' << server_name << '/runtime-vars.xml && '
      java_home_string = "JAVA_HOME=\"$PWD/#{@java_home}\""
      start_script_string = ContainerUtils.space(File.join(LIBERTY_HOME, 'bin', 'server'))
      start_script_string << ContainerUtils.space('run')
      jvm_options
      server_name_string = ContainerUtils.space(server_name)
      "#{create_vars_string}#{java_home_string}#{start_script_string}#{server_name_string}"
    end

    private

    def jvm_options
      return if @java_opts.nil?
      jvm_options_src = Liberty.find_jvm_options(@app_dir)
      if File.exist?(jvm_options_src)
        File.open(jvm_options_src, 'rb') { |f| @java_opts << f.read }
      end
      jvm_options_file = File.new(jvm_options_src, 'w')
      jvm_options_file.puts(@java_opts)
      jvm_options_file.close
      if File.exist?(File.join(@app_dir, JVM_OPTIONS)) && File.exist?(default_server_path)
        default_server_pathname = Pathname.new(default_server_path)
        FileUtils.ln_sf(Pathname.new(File.join(@app_dir, 'jvm.options')).relative_path_from(Pathname.new(default_server_pathname)), default_server_pathname)
      end
    end

    def minify?
      (@environment['minify'].nil? ? (@configuration['minify'] != false) : (@environment['minify'] != 'false')) && java_present?
    end

    def minify_liberty
      Dir.mktmpdir do |root|
        # Create runtime-vars.xml to avoid archive being incorrectly too small
        runtime_vars_file =  File.join(servers_directory, server_name, 'runtime-vars.xml')
        File.open(runtime_vars_file, 'w') do |file|
          file.puts('<server></server>')
        end

        minified_zip = File.join(root, 'minified.zip')
        minify_script_string = "JAVA_HOME=\"#{@app_dir}/#{@java_home}\" #{File.join(liberty_home, 'bin', 'server')} package #{server_name} --include=minify --archive=#{minified_zip} --os=-z/OS"
        # Make it quiet unless there're errors (redirect only stdout)
        minify_script_string << ContainerUtils.space('1>/dev/null')

        system(minify_script_string)

        # Update with minified version only if the generated file exists and not empty.
        if File.size? minified_zip
          system("unzip -qq -d #{root} #{minified_zip}")
          system("rm -rf #{liberty_home}/lib && mv #{root}/wlp/lib #{liberty_home}/lib")
          system("rm -rf #{root}/wlp")
          # Re-create sym-links for application and libraries.
          make_server_script_runnable
          puts 'Using minified liberty.'
        else
          puts 'Minification failed. Continue using the full liberty.'
        end
      end
    end

    def java_present?
      ! @java_home.nil? && File.directory?(File.join(@app_dir, @java_home))
    end

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

    JVM_OPTIONS = 'jvm.options'.freeze

    WEB_INF = 'WEB-INF'.freeze

    META_INF = 'META-INF'.freeze

    def update_server_xml
      server_xml = Liberty.server_xml(@app_dir)
      if server_xml
        server_xml_doc = File.open(server_xml, 'r') { |file| REXML::Document.new(file) }
        server_xml_doc.context[:attribute_quote] = :quote

        endpoints = REXML::XPath.match(server_xml_doc, '/server/httpEndpoint')
        modify_endpoints(endpoints, server_xml_doc)

        include_file = REXML::Element.new('include', server_xml_doc.root)
        include_file.add_attribute('location', 'runtime-vars.xml')

        File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
      elsif Liberty.web_inf(@app_dir) || Liberty.meta_inf(@app_dir)
        server_xml = create_server_xml
        server_xml_application(server_xml)
      else
        raise 'Neither a server.xml nor WEB-INF directory nor a ear was found.'
      end
    end

    # Uses REXML to edit the application attribute in the server.xml. It specifies the location and
    # the type.
    # @return [void]
    def server_xml_application(server_xml)
      server_xml_doc = File.open(server_xml, 'r') { |file| REXML::Document.new(file) }
      application = REXML::XPath.match(server_xml_doc, '/server/application')[0]
      application.attributes['location'] = 'myapp'
      Liberty.web_inf(@app_dir) ? application.attributes['type'] = 'war' : application.attributes['type'] = 'ear'

      File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
    end

    def modify_endpoints(endpoints, server_xml_doc)
      if endpoints.empty?
        endpoint = REXML::Element.new('httpEndpoint', server_xml_doc.root)
      else
        endpoint = endpoints[0]
        endpoints.drop(1).each { |element| element.parent.delete_element(element) }
      end
        endpoint.add_attribute('host', '*')
        endpoint.add_attribute('httpPort', "${#{KEY_HTTP_PORT}}")
        endpoint.delete_attribute('httpsPort')
    end

    # Copies the template server xml into the server directory structure and prepares it
    def create_server_xml
      server_xml_dir = File.join(@app_dir, '.liberty', 'usr', 'servers', 'defaultServer')
      server_xml = File.join(server_xml_dir, 'server.xml')
      FileUtils.mkdir_p(server_xml_dir)
      resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
      FileUtils.cp(File.join(resources, 'server.xml'), default_server_path)
      server_xml
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
      elsif Liberty.server_directory(@app_dir) || Liberty.web_inf(@app_dir) || Liberty.meta_inf(@app_dir)
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
      if !bin_dir?(app_dir)
        if server_xml(app_dir) || web_inf(app_dir) || meta_inf(app_dir)
          version, uri, license = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration) do |candidate_version|
            fail "Malformed Liberty version #{candidate_version}: too many version components" if candidate_version[4]
          end
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

    # Create required file structure from .liberty to the application when a packaged server was pushed or the user pushed from a server
    # directory. If only an application was pushed it sym-links it to the apps directory in the defaultServer.
    # @return [void]
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
      else
        FileUtils.rm_rf(myapp_dir)
        FileUtils.mkdir_p(myapp_dir)
        myapp_pathname = Pathname.new(myapp_dir)
        Pathname.glob(File.join(@app_dir, '*')) do |file|
          FileUtils.ln_sf(file.relative_path_from(myapp_pathname), myapp_dir)
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

    def self.ear_lib(app_dir)
      File.join app_dir, 'lib'
    end

    def self.web_inf(app_dir)
      web_inf = File.join(app_dir, WEB_INF)
      File.directory?(File.join(app_dir, WEB_INF)) ? web_inf : nil
    end

    def self.meta_inf(app_dir)
      meta_inf = File.join(app_dir, META_INF)
      File.directory?(File.join(app_dir, META_INF)) ? meta_inf : nil
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

    def self.contains_type(app_dir, type)
      files = Dir.glob(File.join(app_dir, type))
      files == [] || files == nil ? nil : files
    end

    def self.ear?(app)
      app.include? '.ear'
    end

    def self.bin_dir?(app_dir)
      bin = File.join(app_dir, 'wlp', 'bin')
      dir = File.exist? bin
      if dir
        print "\nPushed a wrongly packaged server please use 'server package --include=user' to package a server\n"
        raise "Pushed a wrongly packaged server please use 'server package --include=user' to package a server"
      end
      dir
    end

    def self.server_xml_directory(app_dir)
      server_xml_dest = File.join(app_dir, LIBERTY_HOME, USR_PATH, '**/server.xml')
      candidates = Dir.glob(server_xml_dest)
      if candidates.size > 1
        raise "\nIncorrect number of servers to deploy (expecting exactly one): #{candidates}\n"
      end
      candidates.any? ? File.dirname(candidates[0]) : nil
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

    def self.find_jvm_options(app_dir)
      server_xml_dir = Liberty.server_xml(app_dir)
      server_xml_dir.nil? ? File.join(app_dir, JVM_OPTIONS) : File.join(File.dirname(server_xml_dir), JVM_OPTIONS)
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

    def self.splat_expand(apps)
      apps.each do |app|
        if File.file? app
          system("unzip -oxq '#{app}' -d ./app")
          FileUtils.rm_rf("#{app}")
        end
      end
    end

    def self.all_extracted?(file_array)
      state = true
      file_array.each do |file|
          state = false if File.file?(file)
      end
      state
    end

  end

end

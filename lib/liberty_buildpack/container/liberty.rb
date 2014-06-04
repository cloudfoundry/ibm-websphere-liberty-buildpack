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

require 'English'
require 'fileutils'
require 'liberty_buildpack/container'
require 'liberty_buildpack/container/container_utils'
require 'liberty_buildpack/container/feature_manager'
require 'liberty_buildpack/container/install_components'
require 'liberty_buildpack/container/optional_components'
require 'liberty_buildpack/container/services_manager'
require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/repository/component_index'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util'
require 'liberty_buildpack/util/application_cache'
require 'liberty_buildpack/util/format_duration'
require 'liberty_buildpack/util/properties'
require 'liberty_buildpack/util/license_management'
require 'open-uri'

module LibertyBuildpack::Container
  # Encapsulates the detect, compile, and release functionality for Liberty applications.
  class Liberty

    include LibertyBuildpack::Util

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Hash] :environment the environment variables available to the application
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [String] :lib_directory the directory that additional libraries are placed in
    # @option context [Hash] :vcap_application the information about the deployed application provided by the Cloud Controller
    # @option context [Hash] :vcap_services the bound services to the application provided by the Cloud Controller
    # @option context [Hash] :license_ids the licenses accepted by the user
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
      @lib_directory = context[:lib_directory]
      @configuration = context[:configuration]
      @vcap_services = context[:vcap_services]
      @vcap_application = context[:vcap_application]
      @license_id = context[:license_ids]['IBM_LIBERTY_LICENSE']
      @environment = context[:environment]
      @apps = apps
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
      liberty_version = Liberty.find_liberty_item(@app_dir, @configuration)[0]
      liberty_version ? [liberty_id(liberty_version)] : nil
    end

    # Downloads and unpacks a Liberty instance
    #
    # @return [void]
    def compile
      @liberty_components_and_uris, @liberty_license = Liberty.find_liberty_files(@app_dir, @configuration)
      unless LibertyBuildpack::Util.check_license(@liberty_license, @license_id)
        print "\nYou have not accepted the IBM Liberty License.\n\nVisit the following uri:\n#{@liberty_license}\n\nExtract the license number (D/N:) and place it inside your manifest file as a ENV property e.g. \nENV: \n  IBM_LIBERTY_LICENSE: {License Number}.\n"
        raise
      end
      download_and_install_liberty
      update_server_xml
      link_application
      make_server_script_runnable
      download_and_install_features
      # Need to do minify here to have server_xml updated and applications and libs linked.
      minify_liberty if minify?
      overlay_java
      set_liberty_system_properties
    end

    # Creates the command to run the Liberty application.
    #
    # @return [String] the command to run the application.
    def release
      server_dir = ' .liberty/usr/servers/' << server_name << '/'
      runtime_vars_file =  server_dir + 'runtime-vars.xml'
      create_vars_string = File.join(LIBERTY_HOME, 'create_vars.rb') << runtime_vars_file << ' && '
      java_home_string = "JAVA_HOME=\"$PWD/#{@java_home}\""
      start_script_string = ContainerUtils.space(File.join(LIBERTY_HOME, 'bin', 'server'))
      start_script_string << ContainerUtils.space('run')
      jvm_options
      server_name_string = ContainerUtils.space(server_name)
      "#{create_vars_string}#{java_home_string}#{start_script_string}#{server_name_string}"
    end

    private

    def jvm_options
      # disable 2-phase (XA) transactions via a -D option, as they are unsupported in
      # Liberty in the cloud (log files need a persistent location, and someone to
      # recover them).
      @java_opts << '-Dcom.ibm.tx.jta.disable2PC=true'

      # add existing options from the jvm.options file, if there is one, to the current
      # options.
      jvm_options_src = File.join(current_server_dir, JVM_OPTIONS)
      if File.exists?(jvm_options_src)
        File.open(jvm_options_src, 'rb') { |f| @java_opts << f.read }
      end

      # re-write the file with all the options.
      FileUtils.mkdir_p File.dirname(jvm_options_src)
      jvm_options_file = File.new(jvm_options_src, 'w')
      jvm_options_file.puts(@java_opts)
      jvm_options_file.close

      # link from server runtime to the options file, if the options file isn't
      # already in the runtime defaultServer directory (if a server.xml was
      # pushed, jvm options will be in the same location, and both are linked
      # to from the runtime).
      if File.exists?(default_server_path) && ! File.exists?(File.join(default_server_path, JVM_OPTIONS))
        default_server_pathname = Pathname.new(default_server_path)
        FileUtils.ln_sf(Pathname.new(jvm_options_src).relative_path_from(default_server_pathname), default_server_path)
      end
    end

    def minify?
      (@environment['minify'].nil? ? (@configuration['minify'] != false) : (@environment['minify'] != 'false')) && java_present?
    end

    def minify_liberty
      print 'Minifying Liberty ... '
      minify_start_time = Time.now
      Dir.mktmpdir do |root|
        minified_zip = File.join(root, 'minified.zip')
        minify_script_string = "JAVA_HOME=\"#{@app_dir}/#{@java_home}\" #{File.join(liberty_home, 'bin', 'server')} package #{server_name} --include=minify --archive=#{minified_zip} --os=-z/OS"
        # Make it quiet unless there're errors (redirect only stdout)
        minify_script_string << ContainerUtils.space('1>/dev/null')
        system(minify_script_string)
        # Update with minified version only if the generated file exists and not empty.
        if File.size? minified_zip
          Liberty.unzip(minified_zip, root)
          if File.exists? icap_extension
            extensions_dir = File.join(root, 'wlp', 'etc', 'extensions')
            system("mkdir -p #{extensions_dir} && cp #{icap_extension} #{extensions_dir}")
          end
          system("rm -rf #{liberty_home}/lib && mv #{root}/wlp/lib #{liberty_home}/lib")
          system("rm -rf #{root}/wlp")
          # Re-create sym-links for application and libraries.
          make_server_script_runnable
          print "(#{(Time.now - minify_start_time).duration}).\n\n"
        else
          print 'failed, will continue using unminified Liberty.\n\n'
        end
      end
    end

    def java_present?
      ! @java_home.nil? && File.directory?(File.join(@app_dir, @java_home))
    end

    def set_liberty_system_properties
      resources_dir = File.expand_path(RESOURCES, File.dirname(__FILE__))
      create_vars_destination = File.join(liberty_home, 'create_vars.rb')
      FileUtils.cp(File.join(resources_dir, 'create_vars.rb'), create_vars_destination)
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

    RESOURCES_DIR = 'resources'.freeze

    JAVA_DIR = '.java'.freeze

    JAVA_OVERLAY_DIR  = '.java-overlay'.freeze

    def update_server_xml
      server_xml = Liberty.server_xml(@app_dir)
      if server_xml
        server_xml_doc = File.open(server_xml, 'r') { |file| REXML::Document.new(file) }
        server_xml_doc.context[:attribute_quote] = :quote

        update_http_endpoint(server_xml_doc)
        update_web_container(server_xml_doc)

        include_file = REXML::Element.new('include', server_xml_doc.root)
        include_file.add_attribute('location', 'runtime-vars.xml')

        # Liberty logs must go into cf logs directory so cf logs command displays them.
        # This is done by modifying server.xml (if it exists)
        include_file = REXML::Element.new('logging', server_xml_doc.root)
        include_file.add_attribute('logDirectory', log_directory)

        # Disable default Liberty Welcome page to avoid returning 200 repsponse before app is ready.
        disable_welcome_page(server_xml_doc)
        # Check if appstate ICAP feature can be used
        appstate_available = check_appstate_feature(server_xml_doc)
        @services_manager.update_configuration(server_xml_doc, false, current_server_dir)

        File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
      elsif Liberty.web_inf(@app_dir) || Liberty.meta_inf(@app_dir)
        # rubocop does not allow methods longer than 25 lines, so following is factored out
        update_server_xml_app(create_server_xml)
        appstate_available = File.file? icap_extension
      else
        raise 'Neither a server.xml nor WEB-INF directory nor a ear was found.'
      end

      add_droplet_yaml if appstate_available
    end

    def update_server_xml_app(filename)
      server_xml_doc = File.open(filename, 'r') { |file| REXML::Document.new(file) }
      server_xml_doc.context[:attribute_quote] = :quote
      @services_manager.update_configuration(server_xml_doc, true, current_server_dir)
      application = REXML::XPath.match(server_xml_doc, '/server/application')[0]
      Liberty.web_inf(@app_dir) ? application.attributes['type'] = 'war' : application.attributes['type'] = 'ear'
      File.open(filename, 'w') { |file| server_xml_doc.write(file) }
    end

    def update_http_endpoint(server_xml_doc)
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
    end

    def update_web_container(server_xml_doc)
      webcontainers = REXML::XPath.match(server_xml_doc, '/server/webContainer')
      if webcontainers.empty?
        webcontainer = REXML::Element.new('webContainer', server_xml_doc.root)
      else
        webcontainer = webcontainers[0]
      end
      webcontainer.add_attribute('trustHostHeaderPort', 'true')
      webcontainer.add_attribute('extractHostHeaderPort', 'true')
    end

    def disable_welcome_page(server_xml_doc)
      dispatchers = REXML::XPath.match(server_xml_doc, '/server/httpDispatcher')
      if dispatchers.empty?
        dispatcher = REXML::Element.new('httpDispatcher', server_xml_doc.root)
      else
        dispatcher = dispatchers[0]
        dispatchers.drop(1).each { |element| element.parent.delete_element(element) }
      end
      dispatcher.add_attribute('enableWelcomePage', 'false')
    end

    def check_appstate_feature(server_xml_doc)
      # Currently appstate can work only with the application named 'myapp' and only if ICAP features
      # are enabled via extensions.
      myapp_apps = REXML::XPath.match(server_xml_doc, '/server/application[@name="myapp"]')
      if File.file?(icap_extension) && ! myapp_apps.empty?

        # Add icap:appstate-1.0 feature
        feature_managers = REXML::XPath.match(server_xml_doc, '/server/featureManager')
        if feature_managers.empty?
          feature_manager = REXML::Element.new('featureManager', server_xml_doc.root)
        else
          feature_manager = feature_managers[0]
        end
        appstate_feature = REXML::Element.new('feature', feature_manager)
        appstate_feature.text = 'icap:appstate-1.0'

        # Turn on marker file using icap_appstate element
        appstate = REXML::Element.new('icap_appstate', server_xml_doc.root)
        appstate.add_attribute('appName', 'myapp')
        appstate.add_attribute('markerPath', '${home}/.liberty.state')

        return true
      end
      false
    end

    def add_droplet_yaml
      resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
      container_root = File.expand_path('..', @app_dir)
      FileUtils.cp(File.join(resources, 'droplet.yaml'), container_root)
      droplet_yaml = File.join(container_root, 'droplet.yaml')
      system "sed -i -e 's|app/.liberty.state|#{File.basename(@app_dir)}/.liberty.state|' #{droplet_yaml}"
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
      # scripts that need to be executable for the feature manager to work
      feature_manager_script = File.join liberty_home, 'bin', 'featureManager'
      system "chmod +x #{feature_manager_script}"
      product_info = File.join liberty_home, 'bin', 'productInfo'
      system "chmod +x #{product_info}"
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

    # Liberty download component names, as used in the component_index.yml file
    # pointed to by the index.yml file The index.yml file is
    # pointed to by the buildpack liberty.yml file.
    COMPONENT_LIBERTY_CORE   = 'liberty_core'.freeze
    COMPONENT_LIBERTY_EXT    = 'liberty_ext'.freeze

    def download_and_install_liberty
      # create a temporary directory where the downloaded files will be extracted to.
      Dir.mktmpdir do |root|
        FileUtils.rm_rf(liberty_home)
        FileUtils.mkdir_p(liberty_home)

        # download and extract the server to a temporary location.
        uri = @liberty_components_and_uris[COMPONENT_LIBERTY_CORE]
        fail 'No Liberty download defined in buildpack.' if uri.nil?
        download_and_unpack_archive(uri, root)

        # read opt-out of service bindings information from env (manifest.yml), and initialise
        # services manager, which will be used to list dependencies for any bound services.
        @services_manager = ServicesManager.new(@vcap_services, runtime_vars_dir(root), @environment['services_autoconfig_excludes'])

        # if the liberty feature manager and repository are not being used to install server
        # features, download the required files from the various configured locations. If the
        # repository is being used it will install features later (after server.xml is updated).
        unless FeatureManager.enabled?(@configuration)
          # download and extract the extended server files to the same location, if required.
          if @services_manager.requires_liberty_extensions? || configured_feature_requires_component?(COMPONENT_LIBERTY_EXT)
            download_and_unpack_archive(uri, root) if (uri = @liberty_components_and_uris.delete(COMPONENT_LIBERTY_EXT))
          end
          # services may provide zips or esas or both. Query services to see what's needed
          # and download and install.
          install_list = InstallComponents.new
          @services_manager.get_required_esas(@liberty_components_and_uris, install_list)
          install_list.zips.each { |zip_uri| download_and_unpack_archive(zip_uri, root) }
          download_and_install_esas(install_list.esas, root)
        end

        # move the server to it's proper location.
        system "mv #{root}/wlp/* #{liberty_home}/"

        # configure icap extension, if required.
        system "sed -i -e 's|productInstall=wlp/|productInstall=#{LIBERTY_HOME}/|' #{icap_extension}" if File.file? icap_extension

        # install any services client jars required.
        @services_manager.install_client_jars(@liberty_components_and_uris, current_server_dir)
      end
    end

    # is the given liberty component required ? It may be non-optional, in which
    # case it is required, or it may be optional, in which case it is required
    # if one of the features it supplies is requested in a server.xml.
    def configured_feature_requires_component?(component)
      features_xpath = OptionalComponents::COMPONENT_NAME_TO_FEATURE_XPATH[component]
      if !features_xpath
        # component is not optional, as it is not in the optional component hash.
        true
      elsif (server_xml = Liberty.server_xml(@app_dir))
        # component is optional and server.xml is supplied, so check requested features.
        server_xml_doc = File.open(server_xml, 'r') { |file| REXML::Document.new(file) }
        server_features = REXML::XPath.match(server_xml_doc, features_xpath)
        server_features.length > 0 ? true : false
      else
        # component is optional, but no server.xml supplied, so no optional features are requested.
        false
      end
    end

    # download and install any features configured in server.xml that are not already
    # present in the liberty server by invoking featureManager with the list of all
    # features, and letting it download and install the missing features from the
    # liberty repository.
    def download_and_install_features
      server_xml = File.join(current_server_dir, SERVER_XML)
      feature_manager = FeatureManager.new(@app_dir, @java_home, @configuration)
      feature_manager.download_and_install_features(server_xml, liberty_home)
    end

    # This method unpacks an archive file. Supported archive types are .zip, .jar, tar.gz and tgz.
    # WARNING: Do not use this method to download archive files that should not be unzipped, such as client driver jars.
    # For each downloaded file, there is a corresponding cached, etag, last_modified, and lock extension.
    def download_and_unpack_archive(uri, root)
      # all file types filtered here should be handled inside block.
      if uri.end_with?('.tgz', '.tar.gz', '.zip', 'jar')
        print "Downloading from #{uri} ... "
        download_start_time = Time.now
        LibertyBuildpack::Util::ApplicationCache.new.get(uri) do |file|
          print "(#{(Time.now - download_start_time).duration}).\n"
          install_archive(file, uri, root)
        end
      else
        # shouldn't happen, expect index.yml or component_index.yml to always
        # name files that can be handled here.
        print("Unknown file type, not downloaded, at #{uri}\n")
      end
      print("\n")
    end

    def install_archive(file, uri, root)
      print 'Installing archive ... '
      install_start_time = Time.now
      if uri.end_with?('.zip', 'jar')
        Liberty.unzip(file.path, root)
      elsif uri.end_with?('tar.gz', '.tgz')
        system "tar -zxf #{file.path} -C #{root} 2>&1"
      else
        # shouldn't really happen
        print("Unknown file type, not installed, at #{uri}.\n")
      end
      puts "(#{(Time.now - install_start_time).duration}).\n"
    end

    def download_and_install_esas(esas, root)
      esas.each do |esa|
        # each esa is an array of two entries, uri and options string
        uri = esa[0]
        options = esa[1]
        print "Downloading from #{uri} ... "
        download_start_time = Time.now
        # for each downloaded file, there is a corresponding cached, etag, last_modified, and lock extension
        LibertyBuildpack::Util::ApplicationCache.new.get(uri) do |file|
          print "(#{(Time.now - download_start_time).duration}).\n"
          install_esa(file, options, root)
        end
      end
    end

    def install_esa(file, options, root)
      print 'Installing feature ... '
      install_start_time = Time.now
      # setup the command and options
      cmd = File.join(root, 'wlp', 'bin', 'featureManager')
      script_string = "JAVA_HOME=\"#{@app_dir}/#{@java_home}\" #{cmd} install #{file.path} #{options}"
      output = `#{script_string}`
      if  $CHILD_STATUS.to_i != 0
        puts "\n #{output}"
      else
        puts "(#{(Time.now - install_start_time).duration}).\n"
      end
      print("\n")
    end

    # Liberty, features and driver jars are downloaded as a number of separate archives and .esa files.
    #
    # Return a map of component name to uri string.
    def self.find_liberty_files(app_dir, configuration)
      config_uri, license = Liberty.find_liberty_item(app_dir, configuration).drop(1)
      # Back to the future. Temporary hack to handle all-in-one liberty core for open source buildpack while the repository is being restructured.
      if config_uri.end_with?('.jar')
        components_and_uris = { COMPONENT_LIBERTY_CORE => config_uri }
      else
        components_and_uris = LibertyBuildpack::Repository::ComponentIndex.new(config_uri).components
      end
      fail "Failed to locate a repository containing a component_index and installable components using uri #{config_uri}." if components_and_uris.nil?
      [components_and_uris, license]
    end

    # Reads the contents of the index file in the Liberty Repository's root to return the matching version, artifact uri, and license
    # of the item that matches the specified version criteria in the buildpack's config file.
    #
    # Returns the version, artifact uri, and license of the requested item in the index file
    def self.find_liberty_item(app_dir, configuration)
      bin_dir?(app_dir)
      if server_xml(app_dir) || web_inf(app_dir) || meta_inf(app_dir)
        version, config_uri, license = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration) do |candidate_version|
          fail "Malformed Liberty version #{candidate_version}: too many version components" if candidate_version[4]
        end
      else
        version = config_uri = nil
      end
      return version, config_uri, license
    rescue => e
      raise RuntimeError, "Liberty container error: #{e.message}", e.backtrace
    end

    def liberty_id(version)
      "liberty-#{version}"
    end

    def link_application
      if Liberty.liberty_directory(@app_dir)
        # Server package. We will delete the .liberty/usr directory and link in the wlp/usr directory from the server package as the usr directory. Copy user esas from
        # .liberty/usr over to wlp/usr before the delete.
        copy_user_features
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

    def copy_user_features
      return unless Dir.exists?(File.join(usr, 'extension', 'lib', 'features'))
      FileUtils.mkdir_p(File.join(@app_dir, 'wlp', 'usr', 'extension', 'lib', 'features'))
      output = `cp #{usr}/extension/lib/features/*.mf #{@app_dir}/wlp/usr/extension/lib/features`
      @logger.warn("copy_user_features copy manifests returned #{output}") if  $CHILD_STATUS.to_i != 0
      output = `cp #{usr}/extension/lib/*.jar #{@app_dir}/wlp/usr/extension/lib`
      @logger.warn("copy_user_features copy jars returned #{output}") if  $CHILD_STATUS.to_i != 0
    end

    def overlay_java
      server_xml_path =  Liberty.liberty_directory(@app_dir)
      if server_xml_path # server package (zip) push
        path_start = File.dirname(server_xml_path)
        overlay_src = File.join(path_start, RESOURCES_DIR, JAVA_OVERLAY_DIR, JAVA_DIR)
      else # WAR or server directory push
        overlay_src = File.join(@app_dir, RESOURCES_DIR, JAVA_OVERLAY_DIR, JAVA_DIR)
      end
      if File.exists?(overlay_src)
        print "Overlaying java from #{overlay_src}\n"
        FileUtils.cp_r(overlay_src, @app_dir)
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

    def icap_extension
      File.join(liberty_home, 'etc', 'extensions', 'icap.properties')
    end

    def log_directory
      if ENV['DYNO'].nil?
        return '../../../../../logs'
      else
        return '../../../../logs'
      end
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
      # return nil if META-INF directory doesn't exist. This mimics behavior of previous implementation.
      meta_inf = File.join(app_dir, META_INF)
      return nil if File.directory?(meta_inf) == false
      # To mimic the behavior of the previous (flawed) implementatation, from here on out we only return nil if we can determine it's a jar
      manifest_file = File.join(app_dir, META_INF, 'MANIFEST.MF')
      return meta_inf if File.exists?(manifest_file) == false
      props = LibertyBuildpack::Util::Properties.new(manifest_file)
      main_class = props['Main-Class']
      main_class.nil? ? meta_inf : nil
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
        print "\nThe pushed server is incorrectly packaged. Use the command 'server package --include=usr' to package a server.\n"
        raise "The pushed server is incorrectly packaged. Use the command 'server package --include=usr' to package a server."
      end
      dir
    end

    def self.server_xml_directory(app_dir)
      server_xml_dest = File.join(app_dir, LIBERTY_HOME, USR_PATH, '**/server.xml')
      candidates = Dir.glob(server_xml_dest)
      if candidates.size > 1
        raise "Incorrect number of servers to deploy (expecting exactly one): #{candidates}"
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

    def current_server_dir
      dir_name = nil
      if Liberty.liberty_directory @app_dir
        # packaged server use case. Push a server zip.
        dir_name = File.join(@app_dir, 'wlp', 'usr', 'servers', server_name)
      elsif Liberty.server_directory @app_dir
        # unpackaged server.xml use case. Push from a server directory
        dir_name = @app_dir
      else
        # push web app use case.
        dir_name = File.join(@app_dir, '.liberty', 'usr', 'servers', 'defaultServer')
      end
      dir_name
    end

    def runtime_vars_dir(root)
      if Liberty.liberty_directory @app_dir
        # packaged server use case. create runtime-vars in the server directory.
        return File.join(@app_dir, 'wlp', 'usr', 'servers', server_name)
      elsif Liberty.server_directory @app_dir
        # unpackaged server.xml use case, push directory. create runtime-vars in the @app_dir
        return @app_dir
      else
        # push web app use case. create runtime-vars in the temp staging area, will get copied at end of staging
        return File.join(root, 'wlp', 'usr', 'servers', 'defaultServer')
      end
    end

    def self.expand_apps(apps)
      apps.each do |app|
        if File.file? app
          temp_directory = "#{app}.tmp"
          Liberty.unzip(app, temp_directory)
          File.delete(app)
          File.rename(temp_directory, app)
        end
      end
    end

    def self.splat_expand(apps)
      apps.each do |app|
        if File.file? app
          Liberty.unzip(app, './app')
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

    def self.unzip(file, dir)
      file = File.expand_path(file)
      FileUtils.mkdir_p (dir)
      Dir.chdir (dir) do
        if File.exists? '/usr/bin/unzip'
          system "unzip -qqo '#{file}'"
        else
          system "jar xf '#{file}'"
        end
      end
    end

  end

end

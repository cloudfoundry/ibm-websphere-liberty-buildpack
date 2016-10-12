# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'liberty_buildpack/container/common_paths'
require 'liberty_buildpack/container/container_utils'
require 'liberty_buildpack/container/feature_manager'
require 'liberty_buildpack/container/install_components'
require 'liberty_buildpack/container/optional_components'
require 'liberty_buildpack/container/services_manager'
require 'liberty_buildpack/container/web_xml_ext'
require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/repository/component_index'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util'
require 'liberty_buildpack/util/cache/application_cache'
require 'liberty_buildpack/util/format_duration'
require 'liberty_buildpack/util/properties'
require 'liberty_buildpack/util/license_management'
require 'liberty_buildpack/util/location_resolver'
require 'liberty_buildpack/util/heroku'
require 'liberty_buildpack/util/xml_utils'
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
    # @option context [CommonPaths] :common_paths the set of paths common across components that components should reference
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
      @common_paths = context[:common_paths] || CommonPaths.new
      @configuration = context[:configuration]
      @vcap_services = Heroku.heroku? ? Heroku.new.generate_vcap_services(ENV) : context[:vcap_services]
      @vcap_application = context[:vcap_application]
      @license_id = context[:license_ids]['IBM_LIBERTY_LICENSE']
      @environment = context[:environment]
      unpack_apps
    end

    # Detects whether this application is a Liberty application.
    #
    # @return [String] returns +liberty-<version>+ if and only if the application has a server.xml, otherwise
    #                  returns +nil+
    def detect
      liberty_version = Liberty.find_liberty_item(@app_dir, @configuration)[0]
      if liberty_version
        # set the relative path from '.liberty/usr/servers/defaultserver'
        @common_paths.relative_location = File.join(LIBERTY_HOME, USR_PATH, SERVERS_PATH, DEFAULT_SERVER)
        [liberty_type, liberty_id(liberty_version)]
      end
    end

    # Downloads and unpacks a Liberty instance
    #
    # @return [void]
    def compile
      Liberty.validate(@app_dir)
      @liberty_components_and_uris, @liberty_license = Liberty.find_liberty_files(@app_dir, @configuration)
      unless LibertyBuildpack::Util.check_license(@liberty_license, @license_id)
        print "\nYou have not accepted the IBM Liberty License.\n\nVisit the following uri:\n#{@liberty_license}\n\nExtract the license number (D/N:) and place it inside your manifest file as a ENV property e.g. \nENV: \n  IBM_LIBERTY_LICENSE: {License Number}.\n"
        raise
      end
      download_and_install_liberty
      link_application
      update_server_xml
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
      jvm_options

      server_dir = ' wlp/usr/servers/' << server_name << '/'
      runtime_vars_file =  server_dir + 'runtime-vars.xml'
      create_vars_string = File.join(LIBERTY_HOME, 'create_vars.rb') << runtime_vars_file << ' &&'
      skip_maxpermsize_string = ContainerUtils.space('WLP_SKIP_MAXPERMSIZE=true')
      java_home_string = ContainerUtils.space("JAVA_HOME=\"$PWD/#{@java_home}\"")
      wlp_user_dir_string = ContainerUtils.space('WLP_USER_DIR="$PWD/wlp/usr"')
      server_script_string = ContainerUtils.space(File.join(LIBERTY_HOME, 'bin', 'server'))

      start_command = "#{create_vars_string}#{skip_maxpermsize_string}#{java_home_string}#{wlp_user_dir_string}#{server_script_string} run #{server_name}"
      move_app

      start_command
    end

    private

    def unpack_apps
      server_xml = Liberty.server_xml(@app_dir)
      if Liberty.web_inf(@app_dir)
        # nothing to do
      elsif Liberty.meta_inf(@app_dir)
        wars = Dir.glob(File.expand_path(File.join(@app_dir, '*.war')))
        Liberty.expand_apps(wars)
      elsif server_xml
        server_path = File.dirname(server_xml)
        ears = Dir.glob("#{server_path}/**/*.ear")
        Liberty.expand_apps(ears)
        wars = Dir.glob("#{server_path}/**/*.war")
        Liberty.expand_apps(wars)
      end
    end

    def move_app
      if Liberty.liberty_directory(@app_dir)
        # Nothing to move
      elsif Liberty.server_directory(@app_dir)
        dest = File.join(@app_dir, '.wlp', USR_PATH, SERVERS_PATH, DEFAULT_SERVER)
        move_and_relink @app_dir, dest
        FileUtils.mv File.join(@app_dir, '.wlp'), File.join(@app_dir, WLP_PATH)
        move_user_features
      else
        dest = File.join(@app_dir, '.wlp', USR_PATH, SERVERS_PATH)
        FileUtils.mkdir_p(dest)
        FileUtils.mv default_server_path, dest
        dest = File.join(dest, DEFAULT_SERVER, 'apps', myapp_name)
        FileUtils.rm_rf(dest)
        move_and_relink @app_dir, dest
        FileUtils.mv File.join(@app_dir, '.wlp'), File.join(@app_dir, WLP_PATH)
        move_user_features
      end
    end

    def move_and_relink(src, dest)
      # Remember symlink targets
      links = Dir[File.join(src, '**', '*')].select { |file| File.symlink?(file) }
      linkmap = Hash[links.map { |link| [Pathname(link).relative_path_from(Pathname(src)), File.realpath(link)] }]
      FileUtils.mkdir_p(dest)
      FileUtils.mv Dir[File.join(src, '*')], dest
      # Relink symlinks to the targets
      linkmap.each do |link, target|
        file = File.join(dest, link)
        FileUtils.ln_sf(Pathname(target).relative_path_from(Pathname(File.dirname(file))), file)
      end
    end

    def move_user_features
      extension_dir = File.join(usr_dir, 'extension')
      FileUtils.mv(extension_dir, File.join(@app_dir, WLP_PATH, USR_PATH)) if Dir.exist?(extension_dir)
    end

    def jvm_options
      # disable 2-phase (XA) transactions via a -D option, as they are unsupported in
      # Liberty in the cloud (log files need a persistent location, and someone to
      # recover them).
      @java_opts << '-Dcom.ibm.tx.jta.disable2PC=true'

      # add existing options from the jvm.options file, if there is one, to the current
      # options, without duplicating options.
      jvm_options_src = File.join(current_server_dir, JVM_OPTIONS)
      if File.exist?(jvm_options_src)
        File.open(jvm_options_src, 'r') do |file|
          file.each_line do |line|
            line.chomp!
            @java_opts << line unless @java_opts.include?(line)
          end
        end
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
      if File.exist?(default_server_path) && !File.exist?(File.join(default_server_path, JVM_OPTIONS))
        default_server_pathname = Pathname.new(default_server_path)
        FileUtils.ln_sf(Pathname.new(jvm_options_src).relative_path_from(default_server_pathname), default_server_path)
      end
    end

    def minify?
      (@environment['minify'].nil? ? (@configuration['minify'] != false) : (@environment['minify'] != 'false')) && java_present?
    end

    def minify_liberty
      print '-----> Minifying Liberty ... '
      minify_start_time = Time.now
      Dir.mktmpdir do |root|
        minified_zip = File.join(root, 'minified.zip')
        minify_script_string = "JAVA_HOME=\"#{@app_dir}/#{@java_home}\" JVM_ARGS="" #{File.join(liberty_home, 'bin', 'server')} package #{server_name} --include=minify --archive=#{minified_zip} --os=-z/OS"
        # Make it quiet unless there're errors (redirect only stdout)
        minify_script_string << ContainerUtils.space('1>/dev/null')
        system(minify_script_string)
        # Update with minified version only if the generated file exists and not empty.
        if File.size? minified_zip
          ContainerUtils.unzip(minified_zip, root)
          if File.exist? icap_extension
            extensions_dir = File.join(root, WLP_PATH, 'etc', 'extensions')
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
      !@java_home.nil? && File.directory?(File.join(@app_dir, @java_home))
    end

    def set_liberty_system_properties
      resources_dir = File.expand_path(RESOURCES, File.dirname(__FILE__))
      create_vars_destination = File.join(liberty_home, 'create_vars.rb')
      FileUtils.cp(File.join(resources_dir, 'create_vars.rb'), create_vars_destination)
      File.chmod(0o755, create_vars_destination)
    end

    KEY_HTTP_PORT = 'port'.freeze

    RESOURCES = File.join('..', '..', '..', 'resources', 'liberty').freeze

    KEY_SUPPORT = 'support'.freeze

    LIBERTY_HOME = '.liberty'.freeze

    DEFAULT_SERVER = 'defaultServer'.freeze

    WLP_PATH = 'wlp'.freeze

    USR_PATH = 'usr'.freeze

    SERVERS_PATH = 'servers'.freeze

    SERVER_XML_GLOB = 'wlp/usr/servers/*/server.xml'.freeze

    SERVER_XML = 'server.xml'.freeze

    JVM_OPTIONS = 'jvm.options'.freeze

    WEB_INF = 'WEB-INF'.freeze

    META_INF = 'META-INF'.freeze

    def update_server_xml
      server_xml = Liberty.server_xml(@app_dir)
      if server_xml
        update_provided_server_xml(server_xml)
      elsif Liberty.web_inf(@app_dir) || Liberty.meta_inf(@app_dir)
        check_default_features
        create_default_server_xml
      else
        raise 'Neither a server.xml nor WEB-INF directory nor a ear was found.'
      end
    end

    def check_default_features
      unless features_set?
        features = config_features(@configuration) || []
        puts format('-----> Warning: Liberty feature set is not specified. Using the default feature set: %s. For the best results, explicitly set the features via the JBP_CONFIG_LIBERTY environment variable or deploy the application as a server directory or packaged server with a custom server.xml file.', features)
      end
    end

    def features_set?
      conf_env = @environment['JBP_CONFIG_LIBERTY']
      unless conf_env.nil?
        begin
          value = YAML.load(conf_env)
          if !config_features(value).nil?
            return true
          elsif value.is_a?(Array)
            value.each do |item|
              return true unless config_features(item).nil?
            end
          end
        rescue SyntaxError
          return false
        end
      end
      false
    end

    def config_features(config)
      config['app_archive']['features'] if config.is_a?(Hash) && !config['app_archive'].nil?
    end

    def update_provided_server_xml(server_xml)
      # Preserve the original configuration before we start modifying it
      FileUtils.cp server_xml.to_s, "#{server_xml}.org"

      server_xml_doc = XmlUtils.read_xml_file(server_xml)

      # Perform inlining of includes prior to adding include for runtime-vars.xml
      # as the file may not exist yet.
      inline_includes(server_xml_doc, File.dirname(server_xml), LocationResolver.new(@app_dir, liberty_home, server_name))

      # add common settings
      update_server_xml_common(server_xml_doc, false)

      XmlUtils.write_formatted_xml_file(server_xml_doc, server_xml)
    end

    def create_default_server_xml
      server_xml_doc = REXML::Document.new('<server></server>')
      server_xml_doc.context[:attribute_quote] = :quote

      default_config = @configuration['app_archive']

      # create featureManager with configured features
      feature_manager = REXML::Element.new('featureManager', server_xml_doc.root)
      unless default_config.nil?
        features = default_config['features'] || []
        features.each do |feature|
          feature_element = REXML::Element.new('feature', feature_manager)
          feature_element.text = feature
        end
      end

      # create application
      application = REXML::Element.new('application', server_xml_doc.root)
      application.attributes['name'] = 'myapp'
      application.attributes['location'] = myapp_name
      application.attributes['type'] = myapp_type
      application.attributes['context-root'] = get_context_root || '/'

      # configure CDI 1.2 implicit bean archive scanning
      cdi = REXML::Element.new('cdi12', server_xml_doc.root)
      scan = default_config.nil? || default_config['implicit_cdi'].nil? ? false : default_config['implicit_cdi']
      cdi.add_attribute('enableImplicitBeanArchives', scan)

      # add common settings
      update_server_xml_common(server_xml_doc, true)

      filename = File.join(default_server_path, SERVER_XML)
      XmlUtils.write_formatted_xml_file(server_xml_doc, filename)
    end

    def update_server_xml_common(server_xml_doc, create)
      update_http_endpoint(server_xml_doc)
      update_web_container(server_xml_doc)
      # add runtime-vars.xml include to server.xml.
      add_runtime_vars(server_xml_doc)
      # Liberty logs must go into cf logs directory so cf logs command displays them.
      update_logs_dir(server_xml_doc)
      # Disable default Liberty Welcome page to avoid returning 200 response before app is ready.
      disable_welcome_page(server_xml_doc)
      # Disable application monitoring
      disable_application_monitoring(server_xml_doc)
      # Disable configuration (server.xml) monitoring
      disable_config_monitoring(server_xml_doc)

      # Check if appstate ICAP feature can be used
      check_appstate_feature(server_xml_doc) if appstate_enabled?

      # update config for services
      @services_manager.update_configuration(server_xml_doc, create, current_server_dir)
    end

    def get_context_root
      ibm_web_xml = WebXmlExt.read(File.join(@app_dir, WEB_INF, 'ibm-web-ext.xml'))
      ibm_web_xml.get_context_root unless ibm_web_xml.nil?
    end

    def update_http_endpoint(server_xml_doc)
      endpoints = REXML::XPath.match(server_xml_doc, '/server/httpEndpoint')

      if endpoints.empty?
        endpoint = REXML::Element.new('httpEndpoint', server_xml_doc.root)
        endpoint.add_attribute('id', 'defaultHttpEndpoint')
      else
        endpoint = endpoints[0]
        endpoints.drop(1).each { |element| element.parent.delete_element(element) }
      end
      if appstate_enabled?
        endpoint.add_attribute('host', '127.0.0.1')
      else
        endpoint.add_attribute('host', '*')
      end
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

    def add_runtime_vars(server_xml_doc)
      include_file = REXML::Element.new('include', server_xml_doc.root)
      include_file.add_attribute('location', 'runtime-vars.xml')
    end

    def update_logs_dir(server_xml_doc)
      elements = REXML::XPath.match(server_xml_doc, '/server/logging')
      if elements.empty?
        logging = REXML::Element.new('logging', server_xml_doc.root)
      else
        logging = elements.last
      end
      logging.add_attribute('logDirectory', '${application.log.dir}')
      logging.add_attribute('consoleLogLevel', 'INFO') if logging.attribute('consoleLogLevel').nil?
    end

    def disable_config_monitoring(server_xml_doc)
      configs = REXML::XPath.match(server_xml_doc, '/server/config')
      if configs.empty?
        config = REXML::Element.new('config', server_xml_doc.root)
        config.add_attribute('updateTrigger', 'mbean')
      end
    end

    def disable_application_monitoring(server_xml_doc)
      application_monitors = REXML::XPath.match(server_xml_doc, '/server/applicationMonitor')
      if application_monitors.empty?
        application_monitor = REXML::Element.new('applicationMonitor', server_xml_doc.root)
        dropins_dir = File.join(current_server_dir, 'dropins')
        dropins_dir_populated = Dir.exist?(dropins_dir) && Dir.entries(dropins_dir).size > 2
        application_monitor.add_attribute('dropinsEnabled', dropins_dir_populated ? 'true' : 'false')
        application_monitor.add_attribute('updateTrigger', 'mbean')
      end
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

    def appstate_enabled?
      config_enabled = @configuration['app_state'].nil? || @configuration['app_state']
      feature_present = File.file?(icap_extension)
      config_enabled && feature_present
    end

    def check_appstate_feature(server_xml_doc)
      # Currently appstate can work only with one application
      apps = REXML::XPath.match(server_xml_doc, '/server/application | /server/webApplication | /server/enterpriseApplication')
      if apps.size >= 1 && !apps[0].attributes['name'].nil?
        # Add appstate-2.0 feature
        feature_managers = REXML::XPath.match(server_xml_doc, '/server/featureManager')
        if feature_managers.empty?
          feature_manager = REXML::Element.new('featureManager', server_xml_doc.root)
        else
          feature_manager = feature_managers[0]
        end
        appstate_feature = REXML::Element.new('feature', feature_manager)
        appstate_feature.text = 'appstate-2.0'

        # Set the apps to be monitored.
        appstate = REXML::Element.new('appstate2', server_xml_doc.root)

        app_names = []

        apps.each do |app|
          app_names << app.attributes['name'] unless app.attributes['name'].nil?
        end

        appstate.add_attribute('appName', app_names.join(', '))
        true
      else
        false
      end
    end

    def make_server_script_runnable
      %w(server featureManager productInfo installUtility).each do |name|
        script = File.join(liberty_home, 'bin', name)
        File.chmod(0o755, script) if File.exist?(script)
      end
    end

    def server_name
      if Liberty.liberty_directory @app_dir
        candidates = Dir[File.join(@app_dir, WLP_PATH, USR_PATH, SERVERS_PATH, '*')]
        raise "Incorrect number of servers to deploy (expecting exactly one): #{candidates}" if candidates.size != 1
        File.basename(candidates[0])
      elsif Liberty.server_directory(@app_dir) || Liberty.web_inf(@app_dir) || Liberty.meta_inf(@app_dir)
        DEFAULT_SERVER
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
        raise 'No Liberty download defined in buildpack.' if uri.nil?
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
          download_and_unpack_archives(install_list.zips, root)
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
      list_configured_features_from_component(component).length > 0
    end

    def list_configured_features_from_component(component)
      feature_names = OptionalComponents.feature_names(component)
      if !feature_names
        # no such component
        []
      elsif (server_xml = Liberty.server_xml(@app_dir))
        feature_manager = FeatureManager.new(@app_dir, @java_home, @configuration)
        feature_names & feature_manager.get_features(server_xml)
      else
        # no server.xml supplied, so check default features.

        default_config = @configuration['app_archive']
        default_features = default_config.nil? ? [] : default_config['features'] || []

        # return an intersection of two arrays
        default_features & feature_names
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

    def download_and_unpack_archives(zips, root)
      zips.each do |entry|
        # each entry is an array of two entries, uri and optional directory string
        uri = entry[0]
        dir = entry[1]
        if dir.nil?
          dir = root
        else
          dir = File.join(@app_dir, dir) unless Pathname.new(dir).absolute?
          FileUtils.mkdir_p(dir)
        end
        download_and_unpack_archive(uri, dir)
      end
    end

    # This method unpacks an archive file. Supported archive types are .zip, .jar, tar.gz and tgz.
    # WARNING: Do not use this method to download archive files that should not be unzipped, such as client driver jars.
    # For each downloaded file, there is a corresponding cached, etag, last_modified, and lock extension.
    def download_and_unpack_archive(uri, root)
      # all file types filtered here should be handled inside block.
      if uri.end_with?('.tgz', '.tar.gz', '.zip', 'jar')
        if uri.include? '://'
          print "-----> Downloading from #{uri} ... "
        else
          filename = File.basename(uri)
          print "-----> Retrieving #{filename} ... "
        end
        download_start_time = Time.now
        LibertyBuildpack::Util::Cache::ApplicationCache.new.get(uri) do |file|
          puts "(#{(Time.now - download_start_time).duration})"
          install_archive(file, uri, root)
        end
      else
        # shouldn't happen, expect index.yml or component_index.yml to always
        # name files that can be handled here.
        puts "Unknown file type, not downloaded, at #{uri}"
      end
    end

    def install_archive(file, uri, root)
      print '         Installing archive ... '
      install_start_time = Time.now
      if uri.end_with?('.zip', 'jar')
        ContainerUtils.unzip(file.path, root)
        puts "(#{(Time.now - install_start_time).duration})"
      elsif uri.end_with?('tar.gz', '.tgz')
        system "tar -zxf #{file.path} -C #{root} 2>&1"
        puts "(#{(Time.now - install_start_time).duration})"
      else
        # shouldn't really happen
        puts "Unknown file type, not installed, at #{uri}."
      end
    end

    def download_and_install_esas(esas, root)
      esas.each do |esa|
        # each esa is an array of two entries, uri and options string
        uri = esa[0]
        options = esa[1]
        if uri.include? '://'
          print "-----> Downloading from #{uri} ... "
        else
          filename = File.basename(uri)
          print "-----> Retrieving #{filename} ... "
        end
        download_start_time = Time.now
        # for each downloaded file, there is a corresponding cached, etag, last_modified, and lock extension
        LibertyBuildpack::Util::Cache::ApplicationCache.new.get(uri) do |file|
          puts "(#{(Time.now - download_start_time).duration})."
          install_esa(file, options, root)
        end
      end
    end

    def install_esa(file, options, root)
      print '         Installing feature ... '
      install_start_time = Time.now
      # setup the command and options
      cmd = File.join(root, WLP_PATH, 'bin', 'featureManager')
      script_string = "JAVA_HOME=\"#{@app_dir}/#{@java_home}\" JVM_ARGS="" #{cmd} install #{file.path} #{options} 2>&1"
      output = `#{script_string}`
      if $CHILD_STATUS.to_i != 0
        puts 'FAILED'
        puts output.to_s
      else
        puts "(#{(Time.now - install_start_time).duration})."
      end
    end

    def inline_includes(server_xml_doc, server_xml_dir, location_resolver)
      REXML::XPath.each(server_xml_doc, '/server/include') do |element|
        location = element.attributes['location']
        optional = element.attributes['optional']
        if location.start_with? 'http:'
          raise 'Configuration files accessible via HTTP are not supported.'
        else
          location = location_resolver.absolute_path(location, server_xml_dir)
          if File.exist? location
            included_xml_doc = XmlUtils.read_xml_file(location)
            inline_includes included_xml_doc, File.dirname(location), location_resolver
            included_xml_doc.root.elements.each { |nested| server_xml_doc.root.insert_after element, nested }
            server_xml_doc.root.delete_element element
          elsif optional !~ /^true$/i
            raise "Configuration file could not be located: #{location}"
          end
        end
      end
    end

    # Liberty, features and driver jars are downloaded as a number of separate archives and .esa files.
    #
    # Return a map of component name to uri string.
    def self.find_liberty_files(app_dir, configuration)
      config_uri, license = Liberty.find_liberty_item(app_dir, configuration).drop(1)
      # Back to the future. Temporary hack to handle all-in-one liberty core for open source buildpack while the repository is being restructured.
      if config_uri.end_with?('.jar', '.zip')
        components_and_uris = { COMPONENT_LIBERTY_CORE => config_uri }
      else
        components_and_uris = LibertyBuildpack::Repository::ComponentIndex.new(config_uri).components
      end
      raise "Failed to locate a repository containing a component_index and installable components using uri #{config_uri}." if components_and_uris.nil?
      [components_and_uris, license]
    end

    # Reads the contents of the index file in the Liberty Repository's root to return the matching version, artifact uri, and license
    # of the item that matches the specified version criteria in the buildpack's config file.
    #
    # Returns the version, artifact uri, and license of the requested item in the index file
    def self.find_liberty_item(app_dir, configuration)
      if server_xml(app_dir) || web_inf(app_dir) || meta_inf(app_dir)
        version, entry = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration) do |candidate_version|
          raise "Malformed Liberty version #{candidate_version}: too many version components" if candidate_version[4]
        end
        if entry.is_a?(Hash)
          type = runtime_type(configuration)
          raise "Runtime type not supported: #{type}" if entry[type].nil?
          return version, entry[type], entry['license']
        else
          return version, entry, nil
        end
      else
        return nil, nil, nil
      end
    rescue => e
      raise RuntimeError, "Liberty container error: #{e.message}", e.backtrace
    end

    def self.runtime_type(configuration)
      type = configuration['type']
      if type.nil? || type.casecmp('webProfile6') == 0
        'uri'
      else
        type
      end
    end

    def liberty_type
      if Liberty.web_inf(@app_dir)
        'WAR'
      elsif Liberty.meta_inf(@app_dir)
        'EAR'
      elsif Liberty.liberty_directory(@app_dir)
        'SVR-PKG'
      elsif Liberty.server_directory(@app_dir)
        'SVR-DIR'
      else
        'unknown'
      end
    end

    def liberty_id(version)
      "liberty-#{version}"
    end

    def link_application
      if Liberty.liberty_directory(@app_dir)
        # Server package. We will delete the .liberty/usr directory and link in the wlp/usr directory from the server package as the usr directory. Copy user esas from
        # .liberty/usr over to wlp/usr before the delete.
        copy_user_features
        FileUtils.rm_rf(usr_dir)
        FileUtils.mkdir_p(liberty_home)
        FileUtils.ln_sf(Pathname.new(File.join(@app_dir, WLP_PATH, USR_PATH)).relative_path_from(Pathname.new(liberty_home)), liberty_home)
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
      return unless Dir.exist?(features_dir)
      FileUtils.mkdir_p(File.join(@app_dir, WLP_PATH, USR_PATH, 'extension', 'lib', 'features'))
      output = `cp #{features_dir}/*.mf #{@app_dir}/wlp/usr/extension/lib/features`
      @logger.warn("copy_user_features copy manifests returned #{output}") if $CHILD_STATUS.to_i != 0
      output = `cp #{extension_lib_dir}/*.jar #{@app_dir}/wlp/usr/extension/lib`
      @logger.warn("copy_user_features copy jars returned #{output}") if $CHILD_STATUS.to_i != 0
    end

    def overlay_java
      server_xml_path =  Liberty.liberty_directory(@app_dir)
      if server_xml_path # server package (zip) push
        path_start = File.dirname(server_xml_path)
        ContainerUtils.overlay_java(path_start, @app_dir)
      else # WAR or server directory push
        ContainerUtils.overlay_java(@app_dir, @app_dir)
      end
    end

    def myapp_type
      Liberty.web_inf(@app_dir) ? 'war' : 'ear'
    end

    def myapp_name
      "myapp.#{myapp_type}"
    end

    def myapp_dir
      File.join(apps_dir, myapp_name)
    end

    def apps_dir
      File.join(default_server_path, 'apps')
    end

    def servers_directory
      File.join(usr_dir, SERVERS_PATH)
    end

    def shared_dir
      File.join(usr_dir, 'shared')
    end

    def shared_resources_dir
      File.join(shared_dir, 'resources')
    end

    def extension_lib_dir
      File.join(usr_dir, 'extension', 'lib')
    end

    def features_dir
      File.join(extension_lib_dir, 'features')
    end

    def default_server_path
      File.join(servers_directory, DEFAULT_SERVER)
    end

    def usr_dir
      File.join(liberty_home, USR_PATH)
    end

    def liberty_home
      File.join(@app_dir, LIBERTY_HOME)
    end

    def icap_extension
      File.join(liberty_home, 'etc', 'extensions', 'icap.properties')
    end

    def self.web_inf(app_dir)
      web_inf = File.join(app_dir, WEB_INF)
      File.directory?(File.join(app_dir, WEB_INF)) && !main_class?(app_dir) ? web_inf : nil
    end

    def self.main_class?(app_dir)
      manifest_file = File.join(app_dir, 'META-INF/MANIFEST.MF')
      if File.exist?(manifest_file)
        props = LibertyBuildpack::Util::Properties.new(manifest_file)
        main_class = props['Main-Class']
        !main_class.nil?
      else
        false
      end
    end

    def self.meta_inf(app_dir)
      # return nil if META-INF directory doesn't exist. This mimics behavior of previous implementation.
      meta_inf = File.join(app_dir, META_INF)
      return nil if File.directory?(meta_inf) == false
      # To mimic the behavior of the previous (flawed) implementatation, from here on out we only return nil if we can determine it's a jar
      manifest_file = File.join(app_dir, META_INF, 'MANIFEST.MF')
      return meta_inf if File.exist?(manifest_file) == false
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

    def self.validate(app_dir)
      bin = File.join(app_dir, WLP_PATH, 'bin')
      dir = File.exist? bin
      if dir
        print "\nThe pushed packaged server contains runtime binaries. Use the command 'server package --include=usr' to package the server without the runtime binaries.\n"
        raise "The pushed packaged server contains runtime binaries. Use the command 'server package --include=usr' to package the server without the runtime binaries."
      end
      if Liberty.server_directory(app_dir) && (Liberty.web_inf(app_dir) || Liberty.meta_inf(app_dir))
        print "\nWAR and EAR files cannot contain a server.xml file in the root directory.\n"
        raise 'WAR and EAR files cannot contain a server.xml file in the root directory.'
      end
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
      if Liberty.liberty_directory @app_dir
        # packaged server use case. Push a server zip.
        File.join(@app_dir, WLP_PATH, USR_PATH, SERVERS_PATH, server_name)
      elsif Liberty.server_directory @app_dir
        # unpackaged server.xml use case. Push from a server directory
        @app_dir
      else
        # push web app use case.
        default_server_path
      end
    end

    def runtime_vars_dir(root)
      if Liberty.liberty_directory @app_dir
        # packaged server use case. create runtime-vars in the server directory.
        File.join(@app_dir, WLP_PATH, USR_PATH, SERVERS_PATH, server_name)
      elsif Liberty.server_directory @app_dir
        # unpackaged server.xml use case, push directory. create runtime-vars in the @app_dir
        @app_dir
      else
        # push web app use case. create runtime-vars in the temp staging area, will get copied at end of staging
        File.join(root, WLP_PATH, USR_PATH, SERVERS_PATH, DEFAULT_SERVER)
      end
    end

    def self.expand_apps(apps)
      apps.each do |app|
        next unless File.file? app
        temp_directory = "#{app}.tmp"
        ContainerUtils.unzip(app, temp_directory)
        File.delete(app)
        File.rename(temp_directory, app)
      end
    end

  end

end

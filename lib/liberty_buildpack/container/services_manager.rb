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

require 'rexml/document'
require 'yaml'
require 'fileutils'
require 'liberty_buildpack/container'
require 'liberty_buildpack/container/install_components'
require 'liberty_buildpack/util/constantize'
require 'liberty_buildpack/util/application_cache'
require 'liberty_buildpack/diagnostics/logger_factory'

module LibertyBuildpack::Container
  # The class that encapsulate access to services and services information.
  class ServicesManager

    def initialize(vcap_services, server_dir)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @logger.debug("init: server dir is #{server_dir} and vcap_services is #{vcap_services}")
      FileUtils.mkdir_p(server_dir)
      @all_services = []
      load_services_config
      parse_vcap_services(vcap_services, server_dir)
    end

    #-----------------------------------------------------------------------------------
    # return true if this service requires Liberty extensions to be installed
    #-----------------------------------------------------------------------------------
    #
    def requires_liberty_extensions?
      @all_services.each do |service|
        return true if service.requires_liberty_extensions?
      end
      false
    end

    #---------------------------------------------------------
    # Install any client driver jars required by the bound services
    #
    # @param uris - the hash of available uris from the repository
    # @param server_dir - the server directory where server.xml is located
    #---------------------------------------------------------
    def install_client_jars(uris, server_dir)
      @logger.debug("uris #{uris}, #{server_dir}")
      lib_dir = File.join(server_dir, 'lib')
      # make sure lib_dir exists.
      FileUtils.mkdir_p(lib_dir)
      existing_jars = Dir[File.join(lib_dir, '*.jar')]
      @logger.debug("existing jars #{existing_jars}")
      to_install = get_urls_for_client_jars(existing_jars, uris)
      Dir.mktmpdir do |root|
        to_install.each do |uri|
          install_jar(root, lib_dir, uri)
        end
      end
    end

    #-------------------------------------------
    # Get required components (prereq zips and esas) from services
    #
    # @param uris - the hash containing the {key, uri} information from the repository
    # @param components - the non-null RequiredComponents to update.
    #---------------------------------------------
    def get_required_esas(uris, components)
      @all_services.each do |service|
        service.get_required_esas(uris, components)
      end
    end

    #-------------------------------
    # Update configuration (server.xml, bootstrap.properties, jvm.options)
    #
    # @param document - the REXML::Document for server.xml
    # @param create - true if create, false if update
    # @param server_dir - the server directory where server.xml physically resides
    #-------------------------------
    def update_configuration(document, create, server_dir)
      lib_dir = File.join(server_dir, 'lib')
      driver_jars = Dir[File.join(lib_dir, '*.jar')]
      driver_dir = '${server.config.dir}/lib'
      @all_services.each do |service|
        if create
          service.create(document.root, server_dir, driver_dir, driver_jars)
        else
          service.update(document.root, server_dir, driver_dir, driver_jars)
        end
      end
    end

    private

    SERVICES_CONFIG_DIR = '../services/config/'.freeze

    def load_services_config
      @config = {}
      # Get the directory where the service yml files are located, read file names then load files and update the config hash.
      services_config_path = File.expand_path(SERVICES_CONFIG_DIR, File.dirname(__FILE__))
      Dir.glob("#{services_config_path}/*.yml").each do |file|
        key = File.basename(file, '.yml')
        @logger.debug("loading service config for #{key} from #{file}")
        @config[key] = YAML.load_file(file)
      end
      @logger.debug("config is #{@config}")
    end

    #-------------------------------------------------
    # Parse the VCAP_SERVICES string and generate the cloud variable in runtime_vars.xml
    # Note: this method will always create the runtime-vars.xml file, even if no services are bound.
    #
    # @param  vcap_services - the hash containing parsed VCAP_SERVICES
    # @param server_dir - the name of the directory where the runtime_vars.xml file should be created
    #-------------------------------------------------
    def parse_vcap_services(vcap_services, server_dir)
      # runtime_vars will not exist, we must ensure it's created in this method
      runtime_vars_doc = REXML::Document.new('<server></server>')
      unless vcap_services.nil?
        vcap_services.each do |service_type, service_data|
          @logger.debug("processing service type #{service_type} and data #{service_data}")
          process_service_type(runtime_vars_doc.root, service_type, service_data)
        end
      end
      runtime_vars = File.join(server_dir, 'runtime-vars.xml')
      File.open(runtime_vars, 'w') { |file| runtime_vars_doc.write(file) }
      @logger.debug("runtime-vars file is is #{runtime_vars}")
      contents = File.readlines(runtime_vars)
      @logger.debug("runtime vars contents is #{contents}")
    end

    #------------------------------------------------------
    # Process all instances of a given service type. For each instance, write the cloud variables to runtime_vars.xml, create the object
    # representing the service instance and store it into @all_services
    #
    # @param element - the REXML root element for runtime_vars.xml
    # @param service_type - the String type as read from VCAP_SERVICES
    # @param service_data - the array holding the instances data
    #------------------------------------------------------
    def process_service_type(element, service_type, service_data)
      # all instances of a given type share the same config data. We have a default type for services that don't have a plugin.
      type = get_service_type(service_type)
      config = @config[type]
      @logger.debug("processing service instances of type #{type}. Config is #{config}")
      service_data.each do |instance|
        service_instance = create_instance(element, type, config, instance)
        @all_services.push(service_instance) if service_instance.nil? == false
      end
    end

    #-----------------------------------
    # find the service type using the vcap_services name
    #-----------------------------------
    def get_service_type(name)
      @config.each_key { |key| return key if name.include?(key) }
      'default'
    end

    #------------------------------------------------
    # Create a service instance
    #
    # @param element - the REXML root element for the runtime-vars.xml document
    # @param type - the service type
    # @param config - the hash containing the config for the service type
    # @param instance_data - the hash containing the service instance data from vcap_services
    #-------------------------------------------------
    def create_instance(element, type, config, instance_data)
      file = config['class_file']
      if file.nil?
        @logger.warn("required configuration attribute class_file missing for service type #{type}. This type cannot be processed")
        return
      end
      class_name = config['class_name']
      if class_name.nil?
        @logger.warn("required configuration attribute class_name missing for service type #{type}. This type cannot be processed")
        return
      end
      @logger.debug("creating service instance #{type}, #{file}, #{class_name}")
      # require the file
      filename = File.join(File.expand_path('..', File.dirname(__FILE__)), 'services', file)
      require filename
      instance = class_name.constantize.new(type, config)
      instance.parse_vcap_services(element, instance_data)
      instance
    end

    #-------------------------------------------
    # Determine the list of client driver jar urls that need to be downloaded.
    #
    # @param existing - a non-null array containing the names of jar files that are already installed.
    # @param urls - a non-null array of available download urls.
    # return a non-null, but possibly empty, array containing the urls that need to be downloaded.
    #---------------------------------------------
    def get_urls_for_client_jars(existing, urls)
      required = []
      @all_services.each do |service|
        needed = service.get_urls_for_client_jars(existing, urls)
        if needed.length > 0
          needed.each do |result|
            required << result
          end
        end
      end
      @logger.debug("required client jars #{required}")
      required
    end

    #-----------------------------------------------------
    # worker method to download/install jars from a specific uri
    #
    # @param root - temp working dir for unzip operations
    # @param lib_dir - directory where jars will be installed to
    # @param uri - the uri to process
    #----------------------------------------------------
    def install_jar(root, lib_dir, uri)
      download_start_time = Time.now
      print "-----> Installing client jar(s) from #{uri} "
      LibertyBuildpack::Util::ApplicationCache.new.get(uri) do |file|
        if file.path.end_with?('zip.cached')
          system "unzip -oq -d #{root} #{file.path} 2>&1"
          Dir.glob("#{root}/**/*.jar").each do |file2|
            system "mv #{file2} #{lib_dir}"
          end
        elsif file.path.end_with?('jar.cached') || file.path.end_with?('rar.cached')
          # extracting the jar name is a real pain. things like File.basepath don't work
          n_one = File.basename(file.path, '.cached')
          name = n_one.split('%2F')[-1]
          @logger.debug("jar copy command is cp #{file.path} #{File.join(lib_dir, name)}")
          FileUtils.copy_file(file.path, File.join(lib_dir, name))
        end # end if
      end # end do |file|
      puts "(#{(Time.now - download_start_time).duration})"
    end
  end  # class
end

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
require 'rexml/document'
require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/services/utils'

module LibertyBuildpack::Services

  #------------------------------------------------------------------------------------
  # The Default class is used as the plugin for services that don't provide a plugin.
  # The Default class will attempt to generate cloud variables for the service, and
  # nothing more. This will work if the service has provided "standard" JSON.
  #------------------------------------------------------------------------------------

  class Default

    #------------------------------------------------------------------------------------
    # Initialize
    #
    # @param type - the vcap_services type
    # @param config - a hash containing the configuration data from the yml file.
    #------------------------------------------------------------------------------------
    def initialize(type, config)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @type = type
      @config = config
      @logger.debug("init type #{@type}")
    end

    #-----------------------------------------------------------------------------------------
    # parse the vcap services and create cloud properties
    #
    # @param element - the root element of the REXML document for runtime-vars.xml
    # @param instance - the hash containing the vcap_services data for this instance
    #------------------------------------------------------------------------------------------
    def parse_vcap_services(element, instance)
      Utils.parse_compliant_vcap_service(element, instance)
    end

    #-----------------------------------------------------------------------------------
    # return true if this service requires Liberty extensions to be installed
    #-----------------------------------------------------------------------------------
    def requires_liberty_extensions?
      false
    end

    #---------------------------------------------
    # Get the list of Liberty features required by this service
    #
    # @param [Set] features - the Set to add the required features to
    #---------------------------------------------
    def get_required_features(features)
    end

    #----------------------------------------------------------------------------------------
    # Use the configured client_jars regular expression to determine which client jars need to be downloaded for this service to function properly
    #
    # @param existing - an array containing the file names of user-provided jars. If the user has provided the jar, no need to download.
    # @param urls - an array containing the available download urls for client jars
    # return - a non-null array of urls. Will be empty if nothing needs to be downloaded.
    #-----------------------------------------------------------------------------------------
    def get_urls_for_client_jars(existing, urls)
      []
    end

    #-------------------------------------------
    # Get required components (prereq zips and esas) from services
    #
    # @param uris - the hash containing the <key, uri> information from the repository
    # @param components - the non-null RequiredComponents to update.
    #---------------------------------------------
    def get_required_esas(uris, components)
      false
    end

    #------------------------------------------------------------------------------------
    # Method to create a datasource stanza (and all related sub-artifacts such as the JDBCDriver) in server.xml.
    #
    # @param doc - the REXML::Document root element for server.xml
    # @param server_dir - the server directory which is the location for bootstrap.properties and jvm.options
    # @param driver_dir - the symbolic name of the directory where client jars are installed
    # @param available_jars - an array containing the names of all installed client driver jars.
    # @raise if a problem was discovered (incoherent or inconsistent existing configuration, for example)
    #------------------------------------------------------------------------------------
    def create(doc, server_dir, driver_dir, available_jars)
    end

    #------------------------------------------------------------------------------------
    # Method to create/update a datasource stanza (and all related sub-artifacts such as the JDBCDriver) in server.xml.
    #
    # @param doc - the REXML::Document root element for server.xml
    # @param server_dir - the server directory which is the location for bootstrap.properties and jvm.options
    # @param driver_dir - the symbolic name of the directory where client jars are installed
    # @param available_jars - an array containing the names of all installed client driver jars.
    # @param number_instances - the number of service instances that update the same service-specific server.xml stanzas
    # @raise if a problem was discovered (incoherent or inconsistent existing configuration, for example)
    #------------------------------------------------------------------------------------
    def update(doc, server_dir, driver_dir, available_jars, number_instances)
    end
  end
end

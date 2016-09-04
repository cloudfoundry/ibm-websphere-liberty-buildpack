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
require 'liberty_buildpack/services/client_jar_utils'
require 'liberty_buildpack/services/utils'

module LibertyBuildpack::Services

  #------------------------------------------------------------------------------------
  # Base class for relational database resources.
  #------------------------------------------------------------------------------------
  class RelationalDatabasePlugin

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
      @features = @config['features']
      @reg_ex = Regexp.new(@config['client_jars'])
      @logger.debug("init type #{@type}, regex #{@reg_ex}")
    end

    #-----------------------------------------------------------------------------------------
    # parse the vcap services and create cloud properties
    #
    # @param element - the root element of the REXML document for runtime-vars.xml
    # @param instance - the hash containing the vcap_services data for this instance
    #------------------------------------------------------------------------------------------
    def parse_vcap_services(element, instance)
      properties = Utils.parse_compliant_vcap_service(element, instance)
      @service_name = properties['service_name']
      # extract the db_name, host, port, user and password from the properties. Since we are using cloud variables for substitution into server.xml,
      # this means we're actually using the keys in the props, not the values. We could use the values for direct substitution.
      conn_prefix = "cloud.services.#{@service_name}.connection."

      # uri is the only property portable between Pivotal, BlueMix, and Heroku
      conn_uri = properties["#{conn_prefix}uri"]
      if conn_uri.nil?
        raise "Resource #{@service_name} does not contain a #{conn_prefix}uri property"
      end
      uri = URI.parse(conn_uri)

      @db_name = get_cloud_property(properties, element, "#{conn_prefix}name", uri.path[1..-1])
      @host = get_cloud_property(properties, element, "#{conn_prefix}host", uri.host)
      @port = get_cloud_property(properties, element, "#{conn_prefix}port", uri.port)
      @user = get_cloud_property(properties, element, "#{conn_prefix}user", uri.user)
      @password = get_cloud_property(properties, element, "#{conn_prefix}password", uri.password)

      # ensure all the cloud properties are always set
      get_cloud_property(properties, element, "#{conn_prefix}hostname", uri.host)
      get_cloud_property(properties, element, "#{conn_prefix}username", uri.user)

      # default JNDI name for DB is jdbc/service_name
      @jndi_name = "jdbc/#{@service_name}"
      # create standard configuration ids.
      @datasource_id = "#{@config_type}-#{@service_name}"
      @connection_manager_id = "#{@config_type}-#{@service_name}-conMgr"
      @properties_id = "#{@config_type}-#{@service_name}-props"
      @jdbc_driver_id = "#{@config_type}-driver"
      @lib_id = "#{@config_type}-library"
      @fileset_id = "#{@config_type}-fileset"
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
      features.merge(@features) unless @features.nil?
    end

    #----------------------------------------------------------------------------------------
    # Use the configured client_jars regular expression to determine which client jars need to be downloaded for this service to function properly
    #
    # @param existing - an array containing the file names of user-provided jars. If the user has provided the jar, no need to download.
    # @param urls - an array containing the available download urls for client jars
    # return - a non-null array of urls. Will be empty if nothing needs to be downloaded.
    #-----------------------------------------------------------------------------------------
    def get_urls_for_client_jars(existing, urls)
      # search the existing jars, if found nothing to do
      if ClientJarUtils.jar_installed?(existing, @reg_ex) == true
        @logger.debug("user supplied client jars for #{@type}")
        return []
      end

      Utils.get_urls_for_client_jars(@config, urls)
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
    # @param doc - the root element of the REXML::Document for server.xml
    # @param server_dir - the server directory which is the location for bootstrap.properties and jvm.options
    # @param driver_dir - the symbolic name of the directory where client jars are installed
    # @param available_jars - an array containing the names of all installed client driver jars.
    # @raise if a problem was discovered (incoherent or inconsistent existing configuration, for example)
    #------------------------------------------------------------------------------------
    def create(doc, server_dir, driver_dir, available_jars)
      # handle client driver jars
      @driver_dir = driver_dir
      @client_jars_string = ClientJarUtils.client_jars_string(ClientJarUtils.get_jar_names(available_jars, @reg_ex))
      @logger.debug("client jars string #{@client_jars_string}")
      create_datasource(doc, @driver_dir)
    end

    #------------------------------------------------------------------------------------
    # Method to create/update a datasource stanza (and all related sub-artifacts such as the JDBCDriver) in server.xml.
    #
    # @param doc - the root element of the REXML::Document for server.xml
    # @param server_dir - the server directory which is the location for bootstrap.properties and jvm.options
    # @param driver_dir - the symbolic name of the directory where client jars are installed
    # @param available_jars - an array containing the names of all installed client driver jars.
    # @param number_instances - the number of service instances that update the same service-specific server.xml stanzas
    # @raise if a problem was discovered (incoherent or inconsistent existing configuration, for example)
    #------------------------------------------------------------------------------------
    def update(doc, server_dir, driver_dir, available_jars, number_instances)
      # handle client driver jars
      @driver_dir = driver_dir
      @client_jars_string = ClientJarUtils.client_jars_string(ClientJarUtils.get_jar_names(available_jars, @reg_ex))
      @logger.debug("client jars string #{@client_jars_string}")
      # Find the datasource config for this service instance.
      datasources = find_datasource(doc, number_instances)
      if datasources.empty?
        @logger.debug("datasource #{@datasource_id} not found, creating it")
        create_datasource(doc, @driver_dir)
      else
        # Find the jdbc driver. Use the jdbc driver to find the shared library.
        jdbc_driver = find_jdbc_driver(doc, datasources)
        library = find_shared_library(doc, jdbc_driver)
        ClientJarUtils.update_library(doc, @service_name, library, @fileset_id, @driver_dir, @client_jars_string)

        # Do not update datasource attributes. Specifically, do not update the jndi name. We do need to update the properties attributes though.
        # find the instance that contains the properties. Liberty only allows one instance of properties.
        properties_element = find_datasource_properties(datasources)
        update_element_attribute(properties_element, 'databaseName', @db_name)
        update_element_attribute(properties_element, 'user', @user)
        update_element_attribute(properties_element, 'password', @password)
        update_element_attribute(properties_element, 'serverName', @host)
        update_element_attribute(properties_element, 'portNumber', @port)
        Utils.add_features(doc, @features)
      end
    end

    private

    def get_cloud_property(properties, element, name, value)
      variable = element.root.elements.to_a("//variable[@name='#{name}']")
      if variable.empty?
        if value.nil?
          return nil
        else
          new_element = REXML::Element.new('variable', element)
          new_element.add_attribute('name', name)
          new_element.add_attribute('value', value)
        end
      end
      "${#{name}}"
    end

    #------------------------------------------------------------------------------------
    # Method to find the single properties instance for a given datasource.
    #
    # @param datasources - an array containing all datasource stanzas with a given id.
    # return the properties Element
    #------------------------------------------------------------------------------------
    def find_datasource_properties(datasources)
      # Get the expected properties based on type.
      expected = @properties_type
      datasources.each do |datasource|
        datasource.elements.each do |element|
          # if name matches exactly, then we are done.
          return element if element.name == expected
          next unless element.name.start_with? 'properties'
          # found the properties element, but it's the wrong type. Update the name to expected type
          @logger.debug("found properties, but wrong type. Found #{element.name} expected #{expected}")
          element.name = expected
          return element
        end
      end
      # if we got here, then we didn't find any properties. Create a properties instance of the expected type.
      props = REXML::Element.new(expected, datasources[0])
      props
    end

    #------------------------------------------------------------------------------------
    # A utility method that can be used to update an attribute for an element.
    #
    # @param element - the Element containing the attribute
    # @param attribute - the String name of attribute to update
    # @param value - the String value of the attribute
    #------------------------------------------------------------------------------------
    def update_element_attribute(element, attribute, value)
      # Simply overwrite the attribute if it exists.
      element.add_attribute(attribute, value)
    end

    #------------------------------------------------------------------------------------
    # A private worker method for the create_or_update_datasource method.
    # This method will only be called when a datasource does not exist.
    #
    # @param doc - the root element of the REXML::Document for server.xml
    # @param lib_dir - the String name of directory where client driver jars are located
    # @raise if an inconsistency is found (shared library already exists but JDBC driver does not)
    #------------------------------------------------------------------------------------
    def create_datasource(doc, lib_dir)
      # create the datasource and set the standard set of attributes.
      ds = REXML::Element.new('dataSource', doc.root)
      ds.add_attribute('id', @datasource_id)
      ds.add_attribute('jdbcDriverRef', @jdbc_driver_id)
      ds.add_attribute('jndiName', @jndi_name)
      ds.add_attribute('transactional', 'true')
      # We don't presently support XA in the cloud. Although Liberty defaults to connection pooled, we need to explicitly specify ConnectionPooledDataSource as some
      # vendors use a single class to implement all datasource types, in which case Liberty will use an XA connection. Avoid this.
      ds.add_attribute('type', 'javax.sql.ConnectionPoolDataSource')
      # add properties element and standard set of attributes.
      props = REXML::Element.new(@properties_type, ds)
      props.add_attribute('id', @properties_id)
      props.add_attribute('databaseName', @db_name)
      props.add_attribute('user', @user)
      props.add_attribute('password', @password)
      props.add_attribute('portNumber', @port)
      props.add_attribute('serverName', @host)
      # allow types that need it to add a ConnectionManager
      create_connection_manager(ds)
      # create the JDBC driver. The JDBC driver will create the shared library.
      create_jdbcdriver(doc, @jdbc_driver_id, @lib_id, @fileset_id, lib_dir)
      Utils.add_features(doc, @features)
    end

    #------------------------------------------------------------------------------------
    # Method to add a connectionManager to the dataSource. Overridden by subclasses that require a connectionManager
    #
    # @param ds - the REXML element for the dataSource
    #------------------------------------------------------------------------------------
    def create_connection_manager(ds)
    end

    #------------------------------------------------------------------------------------
    # Method to create a jdbc driver.
    # This method will also create the library associated with the jdbc driver.
    #
    # @param doc - the root element of the REXML::Document for server.xml
    # @param lib_dir - the directory where client driver jars are located
    # @raise if an internal inconsistency was found.
    #------------------------------------------------------------------------------------
    def create_jdbcdriver(doc, jdbc_driver_id, lib_id, fileset_id, lib_dir)
      # We assume a consistent server.xml. If the datasource did not exist, then this must be a pure "push app" use case. If it is a "push server.xml"
      # case, then failure to find the datasource indicates server.xml is not consistent.
      # TODO: surprisingly, the following will find the driver even if it is imbedded in another datasource.
      # We could probably use XPATH /server/jdbcDriver to limit the search to global.
      drivers = doc.elements.to_a("//jdbcDriver[@id='#{jdbc_driver_id}']")
      # if we find an existing jdbc driver, then one of two things has occurred
      # 1) case of pushing server.xml, but datasource not found (user error)
      # 2) case of pushing a web app and multiple instances of a given resource type (db2) were bound. The JDBC driver was already created when
      #    we created the datasource for a previously processed instance. All instances of a resource type share the same JDBCDriver and library.
      if drivers.empty?
        # Not found, create it. The JDBC Driver is created as a global element and not nested underneath the datasource.
        # puts "jdbcDriver #{jdbc_driver_id} not found, creating it"
        # create the jdbcDriver
        driver = REXML::Element.new('jdbcDriver', doc.root)
        driver.add_attribute('id', jdbc_driver_id)
        driver.add_attribute('libraryRef', lib_id)
        # create the shared library. It should not exist.
        ClientJarUtils.create_global_library(doc, lib_id, fileset_id, lib_dir, @client_jars_string)
      end
    end

    #-----------------------------------------------------------------
    # Return the array of dataSource elements for this service. The returned array will either be empty or will contain the
    # datasource elements for a single datasource. (the configuraton for the single datasource may be partitioned over
    # multiple physical elements.
    #
    # @param doc - the root element of the REXML::Document for server.xml
    # @param number_instances - the number of bound service instances.
    #-----------------------------------------------------------------
    def find_datasource(doc, number_instances)
      # When only one service instance is bound, then we do not require matching config ids. When multiple service instances are bound, we do.
      if number_instances == 1
        # tolerate degenerate condition of multiple datasources configured but only 1 is bound.
        datasources = doc.elements.to_a("//dataSource[@id='#{@datasource_id}']")
        datasources = doc.elements.to_a('//dataSource') if datasources.empty?
      else
        datasources = doc.elements.to_a("//dataSource[@id='#{@datasource_id}']")
      end
      return datasources if datasources.empty?
      raise "The datasource configuration for service #{@service_name} is inconsistent" unless Utils.logical_singleton?(datasources)
      datasources
    end

    #------------------------------------------------------------------------------------
    # Return an array that contains the single JBDC Element for the specified datasource. The one logical datasource
    # may be partitioned over multiple physical Elements.
    #
    # @param doc - the root element of the REXML::Document for server.xml
    # @param datasources - a non-null, non-empty array containing all elements for a given datasource.
    # return the array containing logical Element for the JDBC driver. It may be partitioned over multiple instances.
    # @raise if jdbc driver does not exist or config is incoherent.
    #------------------------------------------------------------------------------------
    def find_jdbc_driver(doc, datasources)
      by_reference = []
      by_containment = []
      datasources.each do |datasource|
        # first check for a jdbcDriverRef attribute. jdbcDriverRefs that point to non-existent jdbcDrivers will be filtered out by the following
        jdbc_attribute = datasource.attribute('jdbcDriverRef').value unless datasource.attribute('jdbcDriverRef').nil?
        unless jdbc_attribute.nil?
          drivers = doc.elements.to_a("//jdbcDriver[@id='#{jdbc_attribute}']")
          drivers.each { |driver| by_reference.push(driver) }
        end
        # next check for jdbcDriver elements
        jdbc_elements = datasource.get_elements('jdbcDriver')
        jdbc_elements.each { |element| by_containment.push(element) }
      end
      # if jdbc drivers have been configured both by containment and by reference, liberty will fail without logging helpful messages.
      raise "Found JDBC driver by-reference and by-containment for #{@service_name}" unless by_reference.empty? || by_containment.empty?
      raise "There is no configured JDBC driver for #{@service_name}" if by_reference.empty? && by_containment.empty?
      jdbc_driver = by_reference.empty? ? by_containment : by_reference
      raise "JDBC Driver configuration for #{@service_name} is inconsistent" unless Utils.logical_singleton?(jdbc_driver)
      jdbc_driver
    end

    #------------------------------------------------------------------------------------
    # Method that finds and returns the library Element for an existing JDBC Driver. The returned Element may be a root element in the
    # document (a shareable library) or it may be a private library contained directly in the JDBC driver.
    #
    # @param doc - the root element of the REXML::Document for server.xml
    # @param jdbc_driver - the array of Elements over which the JDBC driver configuration is distributed.
    # return the Element for the library
    #------------------------------------------------------------------------------------
    def find_shared_library(doc, jdbc_driver)
      by_reference = []
      by_containment = []
      jdbc_driver.each do |driver|
        # by reference - check for libraryRef
        lib_attribute = driver.attribute('libraryRef').value unless driver.attribute('libraryRef').nil?
        unless lib_attribute.nil?
          libs = doc.elements.to_a("//library[@id='#{lib_attribute}']")
          libs.each { |lib| by_reference.push(lib) }
        end
        # next check for contained library elements
        lib_elements = driver.get_elements('library')
        lib_elements.each { |element| by_containment.push(element) }
      end
      raise "JDBC library for #{@service_name} is configured incorrectly. It is configured both by-reference and by-containment" unless by_reference.empty? || by_containment.empty?
      raise "There is no configured JDBC library for #{@service_name}" if by_reference.empty? && by_containment.empty?
      library = by_reference.empty? ? by_containment : by_reference
      library
    end
  end
end

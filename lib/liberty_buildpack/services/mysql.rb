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
require 'liberty_buildpack/services/client_jar_utils'
require 'liberty_buildpack/services/relational_db'

module LibertyBuildpack::Services
  #------------------------------------------------------------------------------------
  # The MySQL class is the class for MySQL relational database resources.
  #------------------------------------------------------------------------------------
  class MySQL < RelationalDatabasePlugin
    #------------------------------------------------------------------------------------
    # Initialize
    #
    # @param type - the vcap_services type
    # @param config - a hash containing the configuration data from the yml file.
    #------------------------------------------------------------------------------------
    def initialize(type, config)
      super(type, config)
      @config_type = 'mysql'
      @properties_type = 'properties'
    end

    #------------------------------------------------------------------------------------
    # Method to add a connectionManager to the dataSource. This subclass overrides empty method in base class.
    #
    # @param ds - the REXML element for the dataSource
    #------------------------------------------------------------------------------------
    def create_connection_manager(ds)
      # add nothing if connection_pool_size attribute is not set in the config.
      cp_size = @config['connection_pool_size']
      return if cp_size.nil?
      cm = REXML::Element.new('connectionManager', ds)
      cm.add_attribute('id', @connection_manager_id)
      cm.add_attribute('maxPoolSize', cp_size)
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
        driver.add_attribute('javax.sql.XADataSource', 'org.mariadb.jdbc.MySQLDataSource')
        driver.add_attribute('javax.sql.ConnectionPoolDataSource', 'org.mariadb.jdbc.MySQLDataSource')
        driver.add_attribute('libraryRef', lib_id)
        # create the shared library. It should not exist.
        ClientJarUtils.create_global_library(doc, lib_id, fileset_id, lib_dir, @client_jars_string)
      end
    end
  end
end

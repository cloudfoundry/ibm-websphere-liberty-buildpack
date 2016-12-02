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
      return if cp_size.nil? || cp_size == -1
      cm = REXML::Element.new('connectionManager', ds)
      cm.add_attribute('id', @connection_manager_id)
      cm.add_attribute('maxPoolSize', cp_size)
    end

    protected

    #------------------------------------------------------------------------------------
    # Method to customize jdbcDriver - called on create or update.
    #
    # @param jdbc_driver - an array containing all jdbcDriver elements with a given id.
    #------------------------------------------------------------------------------------
    def modify_jdbc_driver(jdbcdrivers)
      Utils.find_and_update_attribute(jdbcdrivers, 'javax.sql.XADataSource', 'org.mariadb.jdbc.MySQLDataSource')
      Utils.find_and_update_attribute(jdbcdrivers, 'javax.sql.ConnectionPoolDataSource', 'org.mariadb.jdbc.MySQLDataSource')
    end

    #------------------------------------------------------------------------------------
    # Method to customize dataSource - called on create or update.
    #
    # @param datasources - an array containing all dataSource stanzas with a given id.
    #------------------------------------------------------------------------------------
    def modify_datasource(datasources)
      Utils.find_and_update_attribute(datasources, 'type', 'javax.sql.ConnectionPoolDataSource')
    end

  end
end

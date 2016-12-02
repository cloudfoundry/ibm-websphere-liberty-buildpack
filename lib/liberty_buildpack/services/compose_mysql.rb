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

require 'base64'
require 'rexml/document'
require 'liberty_buildpack/services/client_jar_utils'
require 'liberty_buildpack/services/mysql'

module LibertyBuildpack::Services

  #------------------------------------------------------------------------------------
  # The ComposeMySQL class is the class for Compose for MySQL relational database resources.
  #------------------------------------------------------------------------------------
  class ComposeMySQL < MySQL

    #------------------------------------------------------------------------------------
    # Initialize
    #
    # @param type - the vcap_services type
    # @param config - a hash containing the configuration data from the yml file.
    #------------------------------------------------------------------------------------
    def initialize(type, config, context)
      super(type, config)
      @config_type = 'compose-mysql'
      @app_dir = context[:app_dir]
    end

    #-----------------------------------------------------------------------------------------
    # parse the vcap services and create cloud properties
    #
    # @param element - the root element of the REXML document for runtime-vars.xml
    # @param instance - the hash containing the vcap_services data for this instance
    #------------------------------------------------------------------------------------------
    def parse_vcap_services(element, instance)
      super

      credentials = instance['credentials'] || {}

      # fix the database name as the relational_db uses 'name' from vcap_services
      # which does not match the actual database name in compose
      service_uri = credentials['uri']
      uri = URI.parse(service_uri)
      db_var_name = "cloud.services.#{@service_name}.connection.db"
      new_element = REXML::Element.new('variable', element)
      new_element.add_attribute('name', db_var_name)
      new_element.add_attribute('value', uri.path[1..-1])
      @db_name = "${#{db_var_name}}"

      @mysql_url = 'jdbc:' + URI::Generic.build(
        scheme: 'mysql',
        host: uri.host,
        path: uri.path,
        port: uri.port,
        query: "useSSL=true&serverSslCert=/home/vcap/app/#{CRT_DIRECTORY}/#{CRT_FILE}"
      ).to_s

      @service_cert = credentials['ca_certificate_base64']
      raise "Resource #{@service_name} does not contain a #{conn_prefix}uri property" if @service_cert.nil?
    end

    protected

    #------------------------------------------------------------------------------------
    # Method to customize properties - called on create or update.
    #
    # @param properties_element - the properties element
    #------------------------------------------------------------------------------------
    def modify_properties(properties_element)
      save_cert

      properties_element.add_attribute('url', @mysql_url)
    end

    private

    CRT_DIRECTORY = '.compose_mysql'.freeze

    CRT_FILE = 'cacert.pem'.freeze

    def save_cert
      cert_dir = File.join(@app_dir, CRT_DIRECTORY)
      FileUtils.mkdir_p(cert_dir)
      cert_file = File.join(cert_dir, CRT_FILE)
      File.open(cert_file, 'w+') { |f| f.write(Base64.decode64(@service_cert)) }
    end

  end

end

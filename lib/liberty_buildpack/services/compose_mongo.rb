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
require 'liberty_buildpack/services/mongo'
require 'open3'

module LibertyBuildpack::Services

  #------------------------------------------------------------------------------------
  # The ComposeMongo class is the class for Compose for Mongo database resources.
  #------------------------------------------------------------------------------------
  class ComposeMongo < Mongo

    #------------------------------------------------------------------------------------
    # Initialize
    #
    # @param type - the vcap_services type
    # @param config - a hash containing the configuration data from the yml file.
    #------------------------------------------------------------------------------------
    def initialize(type, config, context)
      super(type, config)
      @config_type = 'compose-mongo'
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
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
      parsed_uri = Mongo.parse_url(service_uri)
      db_var_name = "cloud.services.#{@service_name}.connection.db"
      new_element = REXML::Element.new('variable', element)
      new_element.add_attribute('name', db_var_name)
      new_element.add_attribute('value', parsed_uri['db'])
      @db_name = "${#{db_var_name}}"

      @service_cert = credentials['ca_certificate_base64']
      raise "Resource #{@service_name} does not contain a #{conn_prefix}uri property" if @service_cert.nil?
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
      super

      add_certificate
      add_key_store(doc)
      add_custom_ssl(doc)
    end

    #------------------------------------------------------------------------------------
    # Method to create/update a datasource stanza (and all related sub-artifacts such as the JDBCDriver) in server.xml.
    #
    # @param doc - the REXML::Document root element for server.xml
    # @param server_dir - the server directory which is the location for bootstrap.properties and jvm.options
    # @param driver_dir - the symbolic name of the directory where client jars are installed
    # @param available_jars - an array containing the names of all installed client driver jars.
    # @param [Integer] number_instances - the number of mongo service instances.
    # @raise if a problem was discovered (incoherent or inconsistent existing configuration, for example)
    #------------------------------------------------------------------------------------
    def update(doc, server_dir, driver_dir, available_jars, number_instances)
      super

      add_certificate
      update_keystore_config(doc)
      update_ssl_config(doc)
    end

    protected

    #------------------------------------------------------------------------------------
    # Method to customize properties - called on create
    #
    # @param properties_element - the properties element
    #------------------------------------------------------------------------------------
    def add_properties(properties_element)
      properties_element.add_attribute('sslEnabled', 'true')
      properties_element.add_attribute('sslRef', 'composeMongoSSLConfig')
    end

    #------------------------------------------------------------------------------------
    # Method to update properties - called on update.
    #
    # @param properties_element - the properties element
    #------------------------------------------------------------------------------------
    def update_properties(properties_element)
      Utils.find_and_update_attribute(properties_element, 'sslEnabled', 'true')
      Utils.find_and_update_attribute(properties_element, 'sslRef', 'composeMongoSSLConfig')
    end

    private

    CRT_DIRECTORY = '.compose_mongo'.freeze

    CRT_FILE = 'cacert.pem'.freeze

    KEYSTORE_FILE = 'compose_keystore.jks'.freeze

    def keystore_password
      'liberty-buildpack-keystore-password'
    end

    def key_store
      File.join(@app_dir, CRT_DIRECTORY, KEYSTORE_FILE)
    end

    def compose_cert
      File.join(@app_dir, CRT_DIRECTORY, CRT_FILE)
    end

    def save_cert
      cert_dir = File.join(@app_dir, CRT_DIRECTORY)
      FileUtils.mkdir_p(cert_dir)
      cert_file = File.join(cert_dir, CRT_FILE)
      File.open(cert_file, 'w+') { |f| f.write(Base64.decode64(@service_cert)) }
    end

    def keytool
      File.join(@app_dir, @java_home, '/jre/bin/keytool')
    end

    def add_certificate
      save_cert
      if File.exist?(keytool)
        shell "#{keytool} -import -noprompt -alias mongo_compose -file #{compose_cert} -keystore #{key_store} -storepass #{keystore_password}"
      else
        @logger.error('The keytool could not be found')
      end
    end

    #----------------------------------------------------------------------
    # update_keystore_config
    # logic to determine updates to the ssl keystore stanza
    # @param doc - the REXML::Document root element for server.xml
    #----------------------------------------------------------------------
    def update_keystore_config(doc)
      keystore = doc.elements.to_a("//keyStore[@id='composeMongoKeyStore']")
      if keystore.empty?
        @logger.debug('compose for mongo - update detects no composeMongoKeyStore ssl config - add it')
        add_key_store(doc)
      else
        @logger.debug('compose for mongo - update detects composeMongoKeyStore ssl config - update it')
        update_key_store(doc, keystore)
      end
    end

    #----------------------------------------------------------------------
    # add_key_store
    # adds the defaultKeyStore which is the minimal SSL configuration
    # when there is no existing default ssl configuration found
    # @param doc - the REXML::Document root element for server.xml
    #----------------------------------------------------------------------
    def add_key_store(doc)
      @logger.debug('compose for mongo - in add_key_store')
      ks = REXML::Element.new('keyStore', doc.root)
      ks.add_attribute('id', 'composeMongoKeyStore')
      ks.add_attribute('password', keystore_password)
      ks.add_attribute('type', 'jks')
      ks.add_attribute('location', '/home/vcap/app/.compose_mongo/compose_keystore.jks')
    end

    #----------------------------------------------------------------------
    # update_key_store
    # updates the keyStore stanza
    # @param doc - the REXML::Document root element for server.xml
    # @param keystore - the keystore to be updated
    #----------------------------------------------------------------------
    def update_key_store(doc, keystore)
      @logger.debug('compose for mongo - in update_key_store updating keyStore attribute')
      Utils.find_and_update_attribute(keystore, 'password', keystore_password)
      Utils.find_and_update_attribute(keystore, 'type', 'jks')
      Utils.find_and_update_attribute(keysotre, 'location', key_store)
    end

    #----------------------------------------------------------------------
    # update_ssl_config
    # logic to determine updates to the ssl stanza
    # @param doc - the REXML::Document root element for server.xml
    #----------------------------------------------------------------------
    def update_ssl_config(doc)
      mongo_ssl = doc.elements.to_a("//ssl[@id='composeMongoSSLConfig']")
      if mongo_ssl.empty?
        @logger.debug('compose for mongo - update detects no custom ssl config - add it')
        add_custom_ssl(doc)
      else
        @logger.debug('compose for mongo - update detects custom ssl config - update it')
        update_custom_ssl(doc, mongo_ssl)
      end
    end

    #----------------------------------------------------------------------
    # add_custom_ssl
    # adds a custom ssl configuration for the compose mongo service.
    # @param doc - the REXML::Document root element for server.xml
    #----------------------------------------------------------------------
    def add_custom_ssl(doc)
      @logger.debug('compose for mongo - in add_custom_ssl')
      ssl = REXML::Element.new('ssl', doc.root)
      ssl.add_attribute('id', 'composeMongoSSLConfig')
      ssl.add_attribute('keyStoreRef', 'composeMongoKeyStore')
    end

    #----------------------------------------------------------------------
    # update_custom_ssl
    # updates the ssl stanza for the custom ssl config
    # @param doc - the REXML::Document root element for server.xml
    # @param mongo_ssl - the keystore to be updated
    #----------------------------------------------------------------------
    def update_custom_ssl(doc, mongo_ssl)
      @logger.debug('compose for mongodb - in update_key_store updating keyStore attribute')
      Utils.find_and_update_attribute(mongo_ssl, 'id', 'composeMongoSSLConfig')
      Utils.find_and_update_attribute(mongo_ssl, 'keyStoreRef', 'composeMongoKeyStore')
    end

    # A +system()+-like command that ensure that the execution fails if the command returns a non-zero exit code
    #
    # @param [Object] args The command to run
    # @return [Void]
    def shell(*args)
      Open3.popen3(*args) do |_stdin, stdout, stderr, wait_thr|
        if wait_thr.value != 0
          puts "\nCommand '#{args.join ' '}' has failed"
          puts "STDOUT: #{stdout.gets nil}"
          puts "STDERR: #{stderr.gets nil}"

          raise
        end
      end
    end

  end

end

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
  # The Mongo class is the base class for NOSQL resources.
  #------------------------------------------------------------------------------------
  class Mongo

    #------------------------------------------------------------------------------------
    # Initialize a Mongo Resource Object
    #
    # @param type - the vcap_services type
    # @param config - a hash containing the configuration data from the yml file.
    #------------------------------------------------------------------------------------
    def initialize(type, config)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @type = type
      @config = config
      @reg_ex = Regexp.new(@config['client_jars'])
      @features = @config['features']
      @logger.debug("init type #{@type}, regex #{@reg_ex}")
    end

    #------------------------------------------------------------------------------
    # Process VCAP_SERVICES data and create cloud variables
    #
    # @param element - the REXML root element for runtime-vars.xml file
    # @param instance - the hash containing the service instances data from VCAP_SERVICES
    #------------------------------------------------------------------------------
    def parse_vcap_services(element, instance)
      properties = Utils.parse_compliant_vcap_service(element, instance)
      @service_name = properties['service_name']
      # extract the db_name, host, port, user and password from the properties. Since we are using cloud variables for substitution into server.xml,
      # this means we're actually using the keys in the props, not the values. We could use the values for direct substitution.
      conn_prefix = "cloud.services.#{@service_name}.connection."

      # uri/url is the only property portable between Pivotal, BlueMix, and Heroku
      conn_uri = properties["#{conn_prefix}uri"] || properties["#{conn_prefix}url"]
      if conn_uri.nil?
        raise "Resource #{@service_name} does not contain a #{conn_prefix}uri or #{conn_prefix}url property"
      end
      map = Mongo.parse_url(conn_uri)

      @db_name = get_cloud_property(properties, element, "#{conn_prefix}db", map['db'])
      @hosts = get_cloud_property(properties, element, "#{conn_prefix}hosts", map['hosts'].join(' '))
      @ports = get_cloud_property(properties, element, "#{conn_prefix}ports", map['ports'].join(' '))
      @user = get_cloud_property(properties, element, "#{conn_prefix}user", map['user'])
      @password = get_cloud_property(properties, element, "#{conn_prefix}password", map['password'])

      # ensure all the cloud properties are always set
      get_cloud_property(properties, element, "#{conn_prefix}host", map['hosts'][0])
      get_cloud_property(properties, element, "#{conn_prefix}hostname", map['hosts'][0])
      get_cloud_property(properties, element, "#{conn_prefix}port", map['ports'][0])
      get_cloud_property(properties, element, "#{conn_prefix}username", map['user'])
      get_cloud_property(properties, element, "#{conn_prefix}uri", conn_uri)
      get_cloud_property(properties, element, "#{conn_prefix}url", conn_uri)

      # default JNDI name for NoSQL is mongo/service_name
      @jndi_name = "mongo/#{@service_name}"
      # Generate ids. For Mongo, we need both mongo and mongoDB stanzas.
      @mongo_id = "#{@type}-#{@service_name}"
      @mongodb_id = "#{@mongo_id}-db"
      @lib_id = "#{@type}-library"
      @fileset_id = "#{@type}-fileset"
    end

    # Parse mongodb URL.
    # URL syntax: mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]
    #
    def self.parse_url(mongo_url) # rubocop:disable MethodLength
      map = {}
      nodes = mongo_url.split(',')

      first_node = URI.parse(nodes[0])

      map['user'] = first_node.user unless first_node.user.nil?
      map['password'] = first_node.password unless first_node.password.nil?
      map['hosts'] = [first_node.host]
      map['ports'] = [first_node.port.nil? ? DEFAULT_MONGODB_PORT : first_node.port.to_s]

      if nodes.size == 1
        # single node
        map['db'] = first_node.path[1..-1] unless first_node.path[1..-1].nil?
      else
        # mutiple nodes
        nodes[1..-1].each_with_index do |node, index|
          if index + 2 == nodes.size
            # last node specifies db name
            slash = node.index('/')
            if slash.nil?
              # no db name specified
              host_port = node
            else
              host_port = node[0..slash - 1]
              map['db'] = node[slash + 1..-1]
            end
          else
            host_port = node
          end

          host_port_parts = host_port.split(':')
          map['hosts'] << host_port_parts[0]
          map['ports'] << (host_port_parts.size == 1 ? DEFAULT_MONGODB_PORT : host_port_parts[1])
        end
      end

      map
    end

    #-----------------------------------------------------------------------------------
    # return true if this service requires Liberty extensions to be installed
    #-----------------------------------------------------------------------------------
    #
    def requires_liberty_extensions?
      true
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
    # @ return - a non-null array of urls. Will be empty if nothing needs to be downloaded.
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
    # @param doc - the REXML::Document root element for server.xml
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
      create_mongo(doc, @driver_dir)
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
      # handle client driver jars
      @driver_dir = driver_dir
      @client_jars_string = ClientJarUtils.client_jars_string(ClientJarUtils.get_jar_names(available_jars, @reg_ex))
      @logger.debug("client jars string #{@client_jars_string}")
      create, mongo_dbs, mongos = must_create_configuration?(doc, number_instances)
      if create
        @logger.debug('"No Mongo or MongoDB stanzas were found. Creating configuration')
        create_mongo(doc, @driver_dir)
      else
        # order dependency.
        raise "required mongoDB configuration for service #{@service_name} is missing" if mongo_dbs.empty?
        update_mongo_db(mongo_dbs)
        raise "required mongo configuration for service #{@service_name} is missing" if mongos.empty?
        lib_elements = update_mongo(doc, mongos)
        raise "The configuration for mongo #{@service_name} does not contain a library" if lib_elements.empty?
        ClientJarUtils.update_library(doc, @service_name, lib_elements, @fileset_id, @driver_dir, @client_jars_string)
        Utils.add_features(doc, @features)
      end
    end

    private

    DEFAULT_MONGODB_PORT = '27017'.freeze

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
    # A private worker method that is called by the create method. It is also called by the update method when neither the mongo nor mongoDB
    # configuration exists for a given service instance.
    #
    # @param doc - the REXML::Document for server.xml
    # @param lib_dir - the String name of the directory where client driver jars are located
    #------------------------------------------------------------------------------------
    def create_mongo(doc, lib_dir)
      # create the mongo and set the standard set of attributes.
      mongo = REXML::Element.new('mongo', doc.root)
      mongo.add_attribute('id', @mongo_id)
      mongo.add_attribute('libraryRef', @lib_id)
      mongo.add_attribute('user', @user)
      mongo.add_attribute('password', @password)
      # add hostNames and ports elements.
      hosts = REXML::Element.new('hostNames', mongo)
      hosts.add_text(@hosts)
      ports = REXML::Element.new('ports', mongo)
      ports.add_text(@ports)
      # create the mongoDB
      mongodb = REXML::Element.new('mongoDB', doc.root)
      mongodb.add_attribute('id', @mongodb_id)
      mongodb.add_attribute('databaseName', @db_name)
      mongodb.add_attribute('jndiName', @jndi_name)
      mongodb.add_attribute('mongoRef', @mongo_id)
      # create library if it doesn't already exist. (This may be the second mongo instance and we're sharing the lib)
      libs = doc.elements.to_a("//library[@id='#{@lib_id}']")
      ClientJarUtils.create_global_library(doc, @lib_id, @fileset_id, lib_dir, @client_jars_string, Utils.get_api_visibility(doc)) if libs.empty?
      Utils.add_features(doc, @features)
      Utils.add_library_to_app_classloader(doc, @service_name, @lib_id)
    end

    #-----------------------------------------------------------------
    # Return true if the server.xml contains no mongo or mongoDB entries. If stanzas are detected, also return the array of elements for both.
    #
    # @param doc - the REXML::Document for server.xml
    # @param number_instances - the number of bound service instances.
    #-----------------------------------------------------------------
    def must_create_configuration?(doc, number_instances)
      # When only one service instance is bound, then we do not require matching config ids. When multiple service instances are bound, we do.
      if number_instances == 1
        mongos = doc.elements.to_a('//mongo')
        mongo_dbs = doc.elements.to_a('//mongoDB')
      else
        mongos = doc.elements.to_a("//mongo[@id='#{@mongo_id}']")
        mongo_dbs = doc.elements.to_a("//mongoDB[@id='#{@mongodb_id}']")
      end
      return true, nil, nil if mongos.empty? && mongo_dbs.empty?
      return false, mongo_dbs, mongos # rubocop:disable RedundantReturn
    end

    #------------------------------------------------------------------------------------
    # A private worker method for the update method.
    # Update a single logical mongo_db stanza that can be specified over multiple physical mongo_db stanzas.
    #
    # @param mongo_db - the array of Elements for the given mongoDB. More than 1 if the stanza is split into multiples.
    # @raise if the mongoDB does not contain the expected mongo stanza.
    #------------------------------------------------------------------------------------
    def update_mongo_db(mongo_db)
      # ensure the mongoDB is logically a singleton. This means all mongoDB config stanzas have the same config id.
      raise "The mongoDB configuration for service #{@service_name} is inconsistent" unless Utils.logical_singleton?(mongo_db)
      # update the databaseName
      Utils.find_and_update_attribute(mongo_db, 'databaseName', @db_name)
    end

    #------------------------------------------------------------------------------------
    # A private worker method for the update method.
    # Update a single logical mongo stanza that can be specified over multiple physical mongo stanzas.
    #
    # @param doc - the REXML::Document for server.xml
    # @param mongos - the array of Elements for the given mongo. More than 1 if the stanza is split into multiples.
    # @return - An array containing the Element for the shared library referenced by the mongo stanza.
    # @raise if the mongoDB does not contain the expected library.
    #------------------------------------------------------------------------------------
    def update_mongo(doc, mongos)
      raise "The mongo configuration for service #{@service_name} is inconsistent" unless Utils.logical_singleton?(mongos)
      # Update the user and password attributes if they exist. Create them if they do not.
      Utils.find_and_update_attribute(mongos, 'user', @user)
      Utils.find_and_update_attribute(mongos, 'password', @password)
      find_and_update_endpoint_element(mongos, 'hostNames', @hosts)
      find_and_update_endpoint_element(mongos, 'ports', @ports)
      # delete all hostNames and ports attributes to prevent a conflict with hostNames and ports elements we just added.
      mongos.each do |mongo|
        mongo.delete_attribute('hostNames')
        mongo.delete_attribute('ports')
      end
      # The mongo stanza may contain the library by reference or by containment. It must be one or the other. We rely on Liberty configuration to coherency check.
      lib_id = nil
      lib_element = []
      mongos.each do |mongo|
        lib_id = mongo.attribute('libraryRef').value unless mongo.attribute('libraryRef').nil?
        mongo.get_elements('library').each { |entry| lib_element << entry }
      end
      if lib_element.length > 0
        return lib_element
      else
        return doc.elements.to_a("//library[@id='#{lib_id}']")
      end
    end

    #------------------------------------------------------------------------------------
    # Private worker method that seaches an Element array for the single subelement.
    # Used to update the hostNames and ports Elements.
    # - if the named Element is found, then update it if the text does not equal the specified value.
    # - if the named Element is is not found, then add it to an arbitrary element.
    #
    # @param element_array - the non-null Element array
    # @param name - the String containing the Element name.
    # @param text - the String containing the text value
    #------------------------------------------------------------------------------------
    def find_and_update_endpoint_element(element_array, name, text)
      # A mongo configuration should contain exactly one hostNames and one ports element. Each field may contain multiple, comma-separated entries if the
      # mongo is sharded and distributed. Something the cloud doesn't appear to do today, but expect it to in the future.
      found = false
      element_array.each do |element|
        subelements = element.get_elements(name)
        subelements.each do |subelement|
          found = true
          subelement.text = text if subelement.text != text
        end
      end
      if found == false
        # puts "creating endpoint"
        # Element was not found, add it.
        element = REXML::Element.new(name, element_array[0])
        element.add_text(text)
      end
    end
  end
end

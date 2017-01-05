# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require 'spec_helper'
require 'liberty_buildpack/container/services_manager'
require 'liberty_buildpack/services/compose_mongo'
require 'liberty_buildpack/util/heroku'

module LibertyBuildpack::Services

  describe 'MongoDB' do

    #----------------
    # Helper method to check an xml file agains expected results.
    #
    # @param xml - the name of the xml file file containing the results (server.xml, runtime_vars.xml)
    # @param - expected - the array of strings we expect to find in the xml file, in order.
    #----------------
    def validate_xml(server_xml, expected)
      # Collapse XML into one long String (no cr or lf).
      server_xml_contents_array = File.readlines(server_xml).each(&:strip!)
      server_xml_contents = server_xml_contents_array.join
      # For each String in the expected array, make sure there is a corresponding entry in server.xml
      # make sure we consume all entries in the expected array.
      expected.each do |line|
        expect(server_xml_contents).to include(line)
      end
    end

    describe 'Generate configuration' do

      #----------------------------------------------------------
      # Helper methods to return constants used in checking server.xml contents
      #----------------------------------------------------------
      def get_mongo_id
        'compose-mongo-myNoSql'
      end

      def get_mongodb_id
        "#{get_mongo_id}-db"
      end

      def get_lib_id
        'compose-mongo-library'
      end

      def get_fileset_id
        'compose-mongo-fileset'
      end

      def get_lib_dir
        '${server.config.dir}/lib'
      end

      def get_jndi
        'mongo/myNoSql'
      end

      def get_host
        '${cloud.services.myNoSql.connection.host}'
      end

      def get_port
        '${cloud.services.myNoSql.connection.port}'
      end

      def get_hosts
        '${cloud.services.myNoSql.connection.hosts}'
      end

      def get_ports
        '${cloud.services.myNoSql.connection.ports}'
      end

      def get_user
        '${cloud.services.myNoSql.connection.user}'
      end

      def get_password
        '${cloud.services.myNoSql.connection.password}'
      end

      def get_db
        '${cloud.services.myNoSql.connection.db}'
      end

      def get_keystore_password
        'liberty-buildpack-keystore-password'
      end

      def get_keystore_location
        '/home/vcap/app/.compose_mongo/compose_keystore.jks'
      end

      def check_variables(root, vcap_services, hosts, ports, uri)
        expected_vars = []
        expected_vars << '<variable name=\'cloud.services.myNoSql.connection.db\' value=\'myDb\'/>'
        expected_vars << "variable name=\'cloud.services.myNoSql.connection.host\' value=\'#{hosts[0]}\'/>"
        expected_vars << "<variable name=\'cloud.services.myNoSql.connection.hosts\' value=\'#{hosts.join(' ')}\'/>"
        expected_vars << "<variable name=\'cloud.services.myNoSql.connection.port\' value=\'#{ports[0]}\'/>"
        expected_vars << "<variable name=\'cloud.services.myNoSql.connection.ports\' value=\'#{ports.join(' ')}\'/>"
        expected_vars << '<variable name=\'cloud.services.myNoSql.connection.user\' value=\'myUser\'/>'
        expected_vars << '<variable name=\'cloud.services.myNoSql.connection.password\' value=\'myPassword\'/>'
        expected_vars << "<variable name=\'cloud.services.myNoSql.connection.uri\' value=\'#{uri}\'/>"

        runtime_vars = File.join(root, 'runtime-vars.xml')
        validate_xml(runtime_vars, expected_vars)
      end

      def check_server_xml_create(root, sm)
        server_xml = File.join(root, 'server.xml')
        server_xml_doc = REXML::Document.new('<server><featureManager/></server>')

        sm.update_configuration(server_xml_doc, true, root)

        File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }

        expected_config = []
        expected_config << '<feature>mongodb-2.0</feature>'
        expected_config << '<feature>ssl-1.0</feature>'
        # hostNames and ports are being replaced directly without using the cloud runtime_vars when the mongo.rb code is changed to use the runtime_vars the test must be updated to use the get_hosts and get_ports
        t1 = "<mongo hostNames='myHost.com' id='#{get_mongo_id}' libraryRef='#{get_lib_id}' password='#{get_password}' ports='5432' sslEnabled='true' sslRef='composeMongoSSLConfig' user='#{get_user}'/>"
        expected_config << t1
        expected_config << "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='#{get_jndi}' mongoRef='#{get_mongo_id}'/>"
        expected_config << "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}'/></library>"
        expected_config << "<keyStore id='composeMongoKeyStore' location='#{get_keystore_location}' password='#{get_keystore_password}' type='jks'/>"
        expected_config << "<ssl id='composeMongoSSLConfig' keyStoreRef='composeMongoKeyStore'/>"
        validate_xml(server_xml, expected_config)
      end

      def check_server_xml_update_attribute(root, sm)
        contents = []
        contents << '<server>'
        contents << '<featureManager><feature>jsp-2.2</feature></featureManager>'
        t1 = "<mongo hostNames='noHost' id='#{get_mongo_id}' libraryRef='myLibrary' password='noPassword' ports='1111' user='noUser'/>"
        contents << t1
        contents << "<mongoDB databaseName='noDB' id='#{get_mongodb_id}' jndiName='myJndi' mongoRef='#{get_mongo_id}'/>"
        contents << "<library id='myLibrary'><fileset dir='lib' id='lib-id'/></library>"
        contents << '</server>'
        check_server_xml_update(root, sm, contents)
      end

      def check_server_xml_update_element(root, sm)
        contents = []
        contents << '<server>'
        contents << '<featureManager><feature>jsp-2.2</feature></featureManager>'
        t1 = "<mongo id='#{get_mongo_id}' libraryRef='myLibrary' password='noPassword' user='noUser'>"
        t2 = '<hostNames>noHost</hostNames><ports>1111</ports></mongo>'
        contents << t1 + t2
        contents << "<mongoDB databaseName='noDB' id='#{get_mongodb_id}' jndiName='myJndi' mongoRef='#{get_mongo_id}'/>"
        contents << "<library id='myLibrary'><fileset dir='lib' id='lib-id'/></library>"
        contents << '</server>'
        check_server_xml_update(root, sm, contents)
      end

      def check_server_xml_update(root, sm, contents)
        server_xml_doc = REXML::Document.new(contents.join)
        server_xml = File.join(root, 'server.xml')
        sm.update_configuration(server_xml_doc, false, root)

        File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }

        # check if dataSource properties and library were updated. Other elements should not be updated.
        expected_config = []
        expected_config << '<feature>jsp-2.2</feature>'
        expected_config << '<feature>ssl-1.0</feature>'
        expected_config << '<feature>mongodb-2.0</feature>'
        # hostNames and ports are being replaced directly without using the cloud runtime_vars when the mongo.rb code is changed to use the runtime_vars the test must be updated to use the get_hosts and get_ports
        t1 = "<mongo hostNames='myHost.com' id='#{get_mongo_id}' libraryRef='myLibrary' password='#{get_password}' ports='5432' sslEnabled='true' sslRef='composeMongoSSLConfig' user='#{get_user}'/>"
        expected_config << t1
        expected_config << "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='myJndi' mongoRef='#{get_mongo_id}'/>"
        expected_config << "<library id='myLibrary'><fileset dir='lib' id='lib-id'/><fileset dir='#{get_lib_dir}'/></library>"
        expected_config << "<keyStore id='composeMongoKeyStore' location='#{get_keystore_location}' password='#{get_keystore_password}' type='jks'/>"
        expected_config << "<ssl id='composeMongoSSLConfig' keyStoreRef='composeMongoKeyStore'/>"

        validate_xml(server_xml, expected_config)
      end

      def run_test(vcap_services, hosts, ports, uri)
        Dir.mktmpdir do |root|
          context = { app_dir: root, java_home: '/my/java_home' }
          sm = LibertyBuildpack::Container::ServicesManager.new(vcap_services, root, nil, context)
          check_variables(root, vcap_services, hosts, ports, uri)
          check_server_xml_create(root, sm)
          check_server_xml_update_element(root, sm)
          check_server_xml_update_attribute(root, sm)
        end
      end

      it 'on Bluemix (compose for mongodb)' do
        vcap_services = {}
        mongodb = {}
        mongodb['name'] = 'myNoSql'
        mongodb['label'] = 'compose-for-mongodb'
        mongodb_credentials = {}
        mongodb_credentials['db_type'] = 'mongodb'
        mongodb_credentials['name'] = 'bmix_randomString'
        mongodb_credentials['uri'] = 'mongodb://myUser:myPassword@myHost.com:5432/myDb?ssl=true'
        mongodb_credentials['ca_certificate_base64'] = 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNDVENDQVkrZ0F3SUJBZ0lRYUVwWWNJQnI4SThDK3ZiZTZMQ1FrREFLQmdncWhrak9QUVFEQXpCR01Rc3dDUVlEVlFRR0V3SkQKVGpFYU1CZ0dBMVVFQ2hNUlYyOVRhV2R1SUVOQklFeHBiV2wwWldReEd6QVpCZ05WQkFNVEVrTkJJRmR2VTJsbmJpQkZRME1nVW05dgpkREFlRncweE5ERXhNRGd3TURVNE5UaGFGdzAwTkRFeE1EZ3dNRFU0TlRoYU1FWXhDekFKQmdOVkJBWVRBa05PTVJvd0dBWURWUVFLCkV4RlhiMU5wWjI0Z1EwRWdUR2x0YVhSbFpERWJNQmtHQTFVRUF4TVNRMEVnVjI5VGFXZHVJRVZEUXlCU2IyOTBNSFl3RUFZSEtvWkkKemowQ0FRWUZLNEVFQUNJRFlnQUU0ZjJPdUVNa3E1WjdoY0s2QzYyTjREcmpKTG5Tc2I2SU9zcS9Tcmo1N3l3dnIxRlFQRWQxYlBpVQp0NXY4S0I3RlZNeGpuUlpMVThIbklLdk5yQ1hTZjQvQ3dWcUNYakNMZWxUT0E3V1JmNnFVME5HS1NNeUNCU2FoMVZFUzFuczJvMEl3ClFEQU9CZ05WSFE4QkFmOEVCQU1DQVFZd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBZEJnTlZIUTRFRmdRVXF2M1ZXcVAyaDRzeWhmM1IKTWx1QVJaUHpBN2d3Q2dZSUtvWkl6ajBFQXdNRGFBQXdaUUl4QU9Ta2hMQ0IxVDJ3ZEt5VXBPZ09QUUIwVEtHWGEva05VVHloMlR2MApEYXVwbjc1T2NzcUYxTm5zdFRKRkdHK3JyUUl3ZmNmM2FXTXZvZUdZN3hNUTBYay8wZjdxTzMvZVZ2U1FzUlVSMkxJaUZkQXZ3eVl1CmEvR1JzcEJsOUpybWtPNUsKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo='
        mongodb['credentials'] = mongodb_credentials
        vcap_services['compose-for-mongodb'] = [mongodb]

        run_test(vcap_services, ['myHost.com'], ['5432'], mongodb_credentials['uri'])
      end

    end
  end
end # module

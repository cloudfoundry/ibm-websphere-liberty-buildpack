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

require 'logging_helper'
require 'spec_helper'
require 'liberty_buildpack/container/services_manager'
require 'liberty_buildpack/util/heroku'

module LibertyBuildpack::Services

  describe 'MySQL' do

    include_context 'logging_helper'

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
      def get_ds_id
        'compose-mysql-myDatabase'
      end

      def get_props_id
        'compose-mysql-myDatabase-props'
      end

      def get_driver_id
        'compose-mysql-driver'
      end

      def get_lib_id
        'compose-mysql-library'
      end

      def get_fileset_id
        'compose-mysql-fileset'
      end

      def get_lib_dir
        '${server.config.dir}/lib'
      end

      def get_jndi
        'jdbc/myDatabase'
      end

      def get_host
        '${cloud.services.myDatabase.connection.host}'
      end

      def get_mysql_url
        'jdbc:mysql://myHost.com:5432/myDb?useSSL=true&amp;serverSslCert=/home/vcap/app/.compose_mysql/cacert.pem'
      end

      def get_port
        '${cloud.services.myDatabase.connection.port}'
      end

      def get_user
        '${cloud.services.myDatabase.connection.user}'
      end

      def get_password
        '${cloud.services.myDatabase.connection.password}'
      end

      def get_name
        '${cloud.services.myDatabase.connection.db}'
      end

      def check_variables(root, vcap_services)
        expected_vars = []
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.name\' value=\'foobar\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.db\' value=\'myDb\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.host\' value=\'myHost.com\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.port\' value=\'5432\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.user\' value=\'myUser\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.password\' value=\'myPassword\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.uri\' value=\'mysql://myUser:myPassword@myHost.com:5432/myDb\'/>'

        runtime_vars = File.join(root, 'runtime-vars.xml')
        validate_xml(runtime_vars, expected_vars)
      end

      def check_server_xml_create(root, sm)
        server_xml = File.join(root, 'server.xml')
        server_xml_doc = REXML::Document.new('<server><featureManager/></server>')
        sm.update_configuration(server_xml_doc, true, root)
        File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }

        expected_config = []
        expected_config << '<feature>jdbc-4.1</feature>'
        t1 = "<dataSource id='#{get_ds_id}' jdbcDriverRef='#{get_driver_id}' jndiName='#{get_jndi}' transactional='true' type='javax.sql.ConnectionPoolDataSource'>"
        t2 = "<properties databaseName='#{get_name}' id='#{get_props_id}' password='#{get_password}' portNumber='#{get_port}' serverName='#{get_host}' url='#{get_mysql_url}' user='#{get_user}'/>"
        t3 = '</dataSource>'
        expected_config << t1 + t2 + t3
        driver_info = "javax.sql.ConnectionPoolDataSource='org.mariadb.jdbc.MySQLDataSource' javax.sql.XADataSource='org.mariadb.jdbc.MySQLDataSource'"
        expected_config << "<jdbcDriver id='#{get_driver_id}' #{driver_info} libraryRef='#{get_lib_id}'/>"
        expected_config << "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}'/></library>"

        validate_xml(server_xml, expected_config)
      end

      def check_server_xml_update(root, sm)
        driver_info = "javax.sql.ConnectionPoolDataSource='org.mariadb.jdbc.MySQLDataSource' javax.sql.XADataSource='org.mariadb.jdbc.MySQLDataSource'"

        contents = []
        contents << '<server>'
        contents << '<featureManager><feature>jsp-2.2</feature></featureManager>'
        t1 = "<dataSource id='#{get_ds_id}' jdbcDriverRef='myDriver' jndiName='myJndi' transactional='true'>"
        t2 = "<properties databaseName='noName' password='noPassword' portNumber='1111' serverName='noHost' user='noUser'/>"
        t3 = '</dataSource>'
        contents << t1 + t2 + t3
        contents << "<jdbcDriver id='myDriver' libraryRef='myLibrary'/>"
        contents << "<library id='myLibrary'><fileset dir='lib' id='lib-id'/></library>"
        contents << '</server>'

        server_xml_doc = REXML::Document.new(contents.join)
        server_xml = File.join(root, 'server.xml')
        sm.update_configuration(server_xml_doc, false, root)

        File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }

        # check if dataSource properties and library were updated. Other elements should not be updated.
        expected_config = []
        expected_config << '<feature>jsp-2.2</feature>'
        expected_config << '<feature>jdbc-4.1</feature>'
        t1 = "<dataSource id='#{get_ds_id}' jdbcDriverRef='myDriver' jndiName='myJndi' transactional='true' type='javax.sql.ConnectionPoolDataSource'>"
        t2 = "<properties databaseName='#{get_name}' password='#{get_password}' portNumber='#{get_port}' serverName='#{get_host}' url='#{get_mysql_url}' user='#{get_user}'/>"
        t3 = '</dataSource>'
        expected_config << t1 + t2 + t3
        expected_config << "<jdbcDriver id='myDriver' #{driver_info} libraryRef='myLibrary'/>"
        expected_config << "<library id='myLibrary'><fileset dir='lib' id='lib-id'/><fileset dir='#{get_lib_dir}'/></library>"
        validate_xml(server_xml, expected_config)
      end

      def run_test(vcap_services)
        Dir.mktmpdir do |root|
          context = { app_dir: root }
          sm = LibertyBuildpack::Container::ServicesManager.new(vcap_services, root, nil, context)
          check_variables(root, vcap_services)
          check_server_xml_create(root, sm)
          check_server_xml_update(root, sm)
        end
      end

      it 'on Bluemix (compose for mysql)' do
        vcap_services = {}
        mysql = {}
        mysql['name'] = 'myDatabase'
        mysql['label'] = 'compose-for-mysql'
        mysql_credentials = {}
        mysql_credentials['name'] = 'foobar'
        mysql_credentials['uri'] = 'mysql://myUser:myPassword@myHost.com:5432/myDb'
        mysql_credentials['ca_certificate_base64'] = 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNDVENDQVkrZ0F3SUJBZ0lRYUVwWWNJQnI4SThDK3ZiZTZMQ1FrREFLQmdncWhrak9QUVFEQXpCR01Rc3dDUVlEVlFRR0V3SkQKVGpFYU1CZ0dBMVVFQ2hNUlYyOVRhV2R1SUVOQklFeHBiV2wwWldReEd6QVpCZ05WQkFNVEVrTkJJRmR2VTJsbmJpQkZRME1nVW05dgpkREFlRncweE5ERXhNRGd3TURVNE5UaGFGdzAwTkRFeE1EZ3dNRFU0TlRoYU1FWXhDekFKQmdOVkJBWVRBa05PTVJvd0dBWURWUVFLCkV4RlhiMU5wWjI0Z1EwRWdUR2x0YVhSbFpERWJNQmtHQTFVRUF4TVNRMEVnVjI5VGFXZHVJRVZEUXlCU2IyOTBNSFl3RUFZSEtvWkkKemowQ0FRWUZLNEVFQUNJRFlnQUU0ZjJPdUVNa3E1WjdoY0s2QzYyTjREcmpKTG5Tc2I2SU9zcS9Tcmo1N3l3dnIxRlFQRWQxYlBpVQp0NXY4S0I3RlZNeGpuUlpMVThIbklLdk5yQ1hTZjQvQ3dWcUNYakNMZWxUT0E3V1JmNnFVME5HS1NNeUNCU2FoMVZFUzFuczJvMEl3ClFEQU9CZ05WSFE4QkFmOEVCQU1DQVFZd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBZEJnTlZIUTRFRmdRVXF2M1ZXcVAyaDRzeWhmM1IKTWx1QVJaUHpBN2d3Q2dZSUtvWkl6ajBFQXdNRGFBQXdaUUl4QU9Ta2hMQ0IxVDJ3ZEt5VXBPZ09QUUIwVEtHWGEva05VVHloMlR2MApEYXVwbjc1T2NzcUYxTm5zdFRKRkdHK3JyUUl3ZmNmM2FXTXZvZUdZN3hNUTBYay8wZjdxTzMvZVZ2U1FzUlVSMkxJaUZkQXZ3eVl1CmEvR1JzcEJsOUpybWtPNUsKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo='
        mysql['credentials'] = mysql_credentials
        vcap_services['compose-for-mysql'] = [mysql]

        run_test(vcap_services)
      end

    end

  end

end

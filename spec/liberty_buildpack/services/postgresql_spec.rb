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

  describe 'PostgreSQL' do

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
        'postgresql-myDatabase'
      end

      def get_props_id
        'postgresql-myDatabase-props'
      end

      def get_driver_id
        'postgresql-driver'
      end

      def get_lib_id
        'postgresql-library'
      end

      def get_fileset_id
        'postgresql-fileset'
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
        '${cloud.services.myDatabase.connection.name}'
      end

      def check_variables(root, vcap_services)
        expected_vars = []
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.name\' value=\'myDb\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.host\' value=\'myHost.com\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.port\' value=\'5432\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.user\' value=\'myUser\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.password\' value=\'myPassword\'/>'
        expected_vars << '<variable name=\'cloud.services.myDatabase.connection.uri\' value=\'postgres://myUser:myPassword@myHost.com:5432/myDb\'/>'

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
        t2 = "<properties databaseName='#{get_name}' id='#{get_props_id}' password='#{get_password}' portNumber='#{get_port}' serverName='#{get_host}' user='#{get_user}'/>"
        t3 = '</dataSource>'
        expected_config << t1 + t2 + t3
        driver_info = "javax.sql.ConnectionPoolDataSource='org.postgresql.ds.PGConnectionPoolDataSource' javax.sql.XADataSource='org.postgresql.xa.PGXADataSource'"
        expected_config << "<jdbcDriver id='#{get_driver_id}' #{driver_info} libraryRef='#{get_lib_id}'/>"
        expected_config << "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}'/></library>"
        validate_xml(server_xml, expected_config)
      end

      def check_server_xml_update(root, sm)
        driver_info = "javax.sql.ConnectionPoolDataSource='org.postgresql.ds.PGConnectionPoolDataSource'"

        contents = []
        contents << '<server>'
        contents << '<featureManager><feature>jsp-2.2</feature></featureManager>'
        t1 = "<dataSource id='#{get_ds_id}' jdbcDriverRef='myDriver' jndiName='myJndi' transactional='true'>"
        t2 = "<properties databaseName='noName' password='noPassword' portNumber='1111' serverName='noHost' user='noUser'/>"
        t3 = '</dataSource>'
        contents << t1 + t2 + t3
        contents << "<jdbcDriver id='myDriver' #{driver_info} libraryRef='myLibrary'/>"
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
        t1 = "<dataSource id='#{get_ds_id}' jdbcDriverRef='myDriver' jndiName='myJndi' transactional='true'>"
        t2 = "<properties databaseName='#{get_name}' password='#{get_password}' portNumber='#{get_port}' serverName='#{get_host}' user='#{get_user}'/>"
        t3 = '</dataSource>'
        expected_config << t1 + t2 + t3
        expected_config << "<jdbcDriver id='myDriver' #{driver_info} libraryRef='myLibrary'/>"
        expected_config << "<library id='myLibrary'><fileset dir='lib' id='lib-id'/><fileset dir='#{get_lib_dir}'/></library>"
        validate_xml(server_xml, expected_config)
      end

      def run_test(vcap_services)
        Dir.mktmpdir do |root|
          sm = LibertyBuildpack::Container::ServicesManager.new(vcap_services, root, nil)
          check_variables(root, vcap_services)
          check_server_xml_create(root, sm)
          check_server_xml_update(root, sm)
        end
      end

      it 'on Bluemix (postgresql)' do
        vcap_services = {}
        postgresql = {}
        postgresql['name'] = 'myDatabase'
        postgresql['label'] = 'postgresql-9.1'
        postgresql_credentials = {}
        postgresql_credentials['name'] = 'myDb'
        postgresql_credentials['host'] = 'myHost.com'
        postgresql_credentials['hostname'] = 'myHost.com'
        postgresql_credentials['port'] = '5432'
        postgresql_credentials['user'] = 'myUser'
        postgresql_credentials['username'] = 'myUser'
        postgresql_credentials['password'] = 'myPassword'
        postgresql_credentials['uri'] = 'postgres://myUser:myPassword@myHost.com:5432/myDb'
        postgresql['credentials'] = postgresql_credentials
        vcap_services['postgresql-9.1'] = [postgresql]

        run_test(vcap_services)
      end

      it 'on Bluemix (elephantsql)' do
        vcap_services = {}
        elephantsql = {}
        elephantsql['name'] = 'myDatabase'
        elephantsql['label'] = 'elephantsql'
        elephantsql_credentials = {}
        elephantsql_credentials['uri'] = 'postgres://myUser:myPassword@myHost.com:5432/myDb'
        elephantsql['credentials'] = elephantsql_credentials
        vcap_services['elephantsql'] = [elephantsql]

        run_test(vcap_services)
      end

      it 'on Pivotal' do
        vcap_services = {}
        elephantsql = {}
        elephantsql['name'] = 'myDatabase'
        elephantsql['label'] = 'elephantsql'
        elephantsql['tags'] = %w(relational postgresql)
        elephantsql_credentials = {}
        elephantsql_credentials['uri'] = 'postgres://myUser:myPassword@myHost.com:5432/myDb'
        elephantsql['credentials'] = elephantsql_credentials
        vcap_services['elephantsql'] = [elephantsql]

        run_test(vcap_services)
      end

      it 'on Heroku' do
        env = {}
        env['HEROKU_POSTGRESQL_RED_URL'] = 'postgres://myUser:myPassword@myHost.com:5432/myDb'
        env['SERVICE_NAME_MAP'] = 'HEROKU_POSTGRESQL_RED_URL=myDatabase'
        vcap_services = LibertyBuildpack::Util::Heroku.new.generate_vcap_services(env)

        run_test(vcap_services)
      end

    end

    describe 'Override configuration' do

      let(:application_cache) { double('ApplicationCache') }

      it 'should use user defined repository and version' do
        Dir.mktmpdir do |root|
          vcap_services = {}
          elephantsql = {}
          elephantsql['name'] = 'myDatabase'
          elephantsql['label'] = 'elephantsql'
          elephantsql_credentials = {}
          elephantsql_credentials['uri'] = 'postgres://myUser:myPassword@myHost.com:5432/myDb'
          elephantsql['credentials'] = elephantsql_credentials
          vcap_services['elephantsql'] = [elephantsql]

          FileUtils.mkdir(File.join(root, 'cache'))
          index_file = "#{root}/cache/index.yml"
          cached_file = "#{root}/cache/foo.jar.cached"
          File.open(index_file, 'w') do |file|
            file.puts('---')
            file.puts("11.0.0: #{cached_file}")
          end
          FileUtils.cp('spec/fixtures/wlp-stub.jar', cached_file)

          LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(index_file).and_yield(File.open(index_file))
          application_cache.stub(:get).with(cached_file).and_yield(File.open(cached_file))

          ENV['LBP_SERVICE_CONFIG_POSTGRESQL'] = "{driver: { repository_root: #{root}/cache, version: 11.+ }}"

          sm = LibertyBuildpack::Container::ServicesManager.new(vcap_services, root, nil)
          file = File.join(root, 'lib', 'foo.jar')
          expect(File).not_to exist(file)
          sm.install_client_jars([], root)
          expect(File).to exist(file)
        end
      end
    end
  end

end

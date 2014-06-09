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
require 'liberty_buildpack/services/mongo'
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
      server_xml_contents_array = File.readlines(server_xml).each do |line|
        line.strip!
      end
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
        'mongo-myNoSql'
      end

      def get_mongodb_id
        "#{get_mongo_id}-db"
      end

      def get_lib_id
        'mongo-library'
      end

      def get_fileset_id
        'mongo-fileset'
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
        t1 = "<mongo id='#{get_mongo_id}' libraryRef='#{get_lib_id}' password='#{get_password}' user='#{get_user}'>"
        t2 = "<hostNames>#{get_hosts}</hostNames><ports>#{get_ports}</ports></mongo>"
        expected_config << t1 + t2
        expected_config << "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='#{get_jndi}' mongoRef='#{get_mongo_id}'/>"
        expected_config << "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}'/></library>"
        validate_xml(server_xml, expected_config)
      end

      def check_server_xml_update(root, sm)
        contents = []
        contents << '<server>'
        contents << '<featureManager><feature>jsp-2.2</feature></featureManager>'
        t1 = "<mongo id='#{get_mongo_id}' libraryRef='myLibrary' password='noPassword' user='noUser'>"
        t2 = '<hostNames>noHost</hostNames><ports>1111</ports></mongo>'
        contents << t1 + t2
        contents << "<mongoDB databaseName='noDB' id='#{get_mongodb_id}' jndiName='myJndi' mongoRef='#{get_mongo_id}'/>"
        contents << "<library id='myLibrary'><fileset dir='lib' id='lib-id'/></library>"
        contents << '</server>'

        server_xml_doc = REXML::Document.new(contents.join)
        server_xml = File.join(root, 'server.xml')
        sm.update_configuration(server_xml_doc, false, root)

        File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }

        # check if dataSource properties and library were updated. Other elements should not be updated.
        expected_config = []
        expected_config << '<feature>jsp-2.2</feature>'
        expected_config << '<feature>mongodb-2.0</feature>'
        t1 = "<mongo id='#{get_mongo_id}' libraryRef='myLibrary' password='#{get_password}' user='#{get_user}'>"
        t2 = "<hostNames>#{get_hosts}</hostNames><ports>#{get_ports}</ports></mongo>"
        expected_config << t1 + t2
        expected_config << "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='myJndi' mongoRef='#{get_mongo_id}'/>"
        expected_config << "<library id='myLibrary'><fileset dir='lib' id='lib-id'/><fileset dir='#{get_lib_dir}'/></library>"
        validate_xml(server_xml, expected_config)
      end

      def run_test(vcap_services, hosts, ports, uri)
        Dir.mktmpdir do |root|
          sm = LibertyBuildpack::Container::ServicesManager.new(vcap_services, root, nil)
          check_variables(root, vcap_services, hosts, ports, uri)
          check_server_xml_create(root, sm)
          check_server_xml_update(root, sm)
        end
      end

      it 'on Bluemix (mongodb)' do
        vcap_services = {}
        mongodb = {}
        mongodb['name'] = 'myNoSql'
        mongodb['label'] = 'mongodb-2.2'
        mongodb_credentials = {}
        mongodb_credentials['name'] = '1111'
        mongodb_credentials['db'] = 'myDb'
        mongodb_credentials['host'] = 'myHost.com'
        mongodb_credentials['hostname'] = 'myHost.com'
        mongodb_credentials['port'] = '5432'
        mongodb_credentials['username'] = 'myUser'
        mongodb_credentials['password'] = 'myPassword'
        mongodb_credentials['url'] = 'mongodb://myUser:myPassword@myHost.com:5432/myDb'
        mongodb['credentials'] = mongodb_credentials
        vcap_services['mongodb-2.2'] = [mongodb]

        run_test(vcap_services, ['myHost.com'], ['5432'], mongodb_credentials['url'])
      end

      it 'on Bluemix (MongoLab)' do
        vcap_services = {}
        mongolab = {}
        mongolab['name'] = 'myNoSql'
        mongolab['label'] = 'MongoLab-1.0'
        mongolab_credentials = {}
        mongolab_credentials['db'] = 'myDb'
        mongolab_credentials['host'] = 'myHost.com'
        mongolab_credentials['hostname'] = 'myHost.com'
        mongolab_credentials['port'] = '5432'
        mongolab_credentials['username'] = 'myUser'
        mongolab_credentials['password'] = 'myPassword'
        mongolab_credentials['url'] = 'mongodb://myUser:myPassword@myHost.com:5432/myDb'
        mongolab['credentials'] = mongolab_credentials
        vcap_services['MongoLab-1.0'] = [mongolab]

        run_test(vcap_services, ['myHost.com'], ['5432'], mongolab_credentials['url'])
      end

      it 'on Pivotal (MongoLab)' do
        vcap_services = {}
        mongolab = {}
        mongolab['name'] = 'myNoSql'
        mongolab['label'] = 'mongolab'
        mongolab['tags'] = %w(document mongodb)
        mongolab_credentials = {}
        mongolab_credentials['uri'] = 'mongodb://myUser:myPassword@myHost.com:5432/myDb'
        mongolab['credentials'] = mongolab_credentials
        vcap_services['mongolab'] = [mongolab]

        run_test(vcap_services, ['myHost.com'], ['5432'], mongolab_credentials['uri'])
      end

      it 'on Heroku (MongoHQ)' do
        env = {}
        env['MONGOHQ_URL'] = 'mongodb://myUser:myPassword@myHost.com:5432/myDb'
        env['SERVICE_NAME_MAP'] = 'MONGOHQ_URL=myNoSql'
        vcap_services = LibertyBuildpack::Util::Heroku.new.generate_vcap_services(env)

        run_test(vcap_services, ['myHost.com'], ['5432'], env['MONGOHQ_URL'])
      end

      it 'on Heroku (MongoHQ, clustered)' do
        env = {}
        env['MONGOHQ_URL'] = 'mongodb://myUser:myPassword@myHost.com:5432,myHost2.com,myHost3.net:1234/myDb'
        env['SERVICE_NAME_MAP'] = 'MONGOHQ_URL=myNoSql'
        vcap_services = LibertyBuildpack::Util::Heroku.new.generate_vcap_services(env)

        run_test(vcap_services, %w{myHost.com myHost2.com myHost3.net}, %w{5432 27017 1234}, env['MONGOHQ_URL'])
      end

      it 'on Heroku (MongoLab)' do
        env = {}
        env['MONGOLAB_URI'] = 'mongodb://myUser:myPassword@myHost.com:5432/myDb'
        env['SERVICE_NAME_MAP'] = 'MONGOLAB_URI=myNoSql'
        vcap_services = LibertyBuildpack::Util::Heroku.new.generate_vcap_services(env)

        run_test(vcap_services, ['myHost.com'], ['5432'], env['MONGOLAB_URI'])
      end

      it 'on Heroku (MongoSoup)' do
        env = {}
        env['MONGOSOUP_URL'] = 'mongodb://myUser:myPassword@myHost.com:5432/myDb'
        env['SERVICE_NAME_MAP'] = 'MONGOSOUP_URL=myNoSql'
        vcap_services = LibertyBuildpack::Util::Heroku.new.generate_vcap_services(env)

        run_test(vcap_services, ['myHost.com'], ['5432'], env['MONGOSOUP_URL'])
      end

      it 'on Heroku (MongoSoup, no port)' do
        env = {}
        env['MONGOSOUP_URL'] = 'mongodb://myUser:myPassword@myHost.com/myDb'
        env['SERVICE_NAME_MAP'] = 'MONGOSOUP_URL=myNoSql'
        vcap_services = LibertyBuildpack::Util::Heroku.new.generate_vcap_services(env)

        run_test(vcap_services, ['myHost.com'], ['27017'], env['MONGOSOUP_URL'])
      end

    end

    describe 'Parse URL' do

      def check_map(map, expected_db, expected_user, expected_password, expected_ports, expected_hosts)
        if expected_db.nil?
          expect(map['db']).to be_nil
        else
          expect(map['db']).to match(expected_db)
        end
        if expected_user.nil?
          expect(map['user']).to be_nil
        else
          expect(map['user']).to match(expected_user)
        end
        if expected_password.nil?
          expect(map['password']).to be_nil
        else
          expect(map['password']).to match(expected_password)
        end
        expect(map['ports']).to have(expected_ports.size).items
        expected_ports.each_with_index do | value, index |
          expect(map['ports'][index]).to match(value)
        end
        expect(map['hosts']).to have(expected_hosts.size).items
        expected_hosts.each_with_index do | value, index |
          expect(map['hosts'][index]).to match(value)
        end
      end

      it 'One node' do
        # with port
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myUser:myPassword@myHost.com:5432/myDb')
        check_map(map, 'myDb', 'myUser', 'myPassword', ['5432'], ['myHost'])
        # without port
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myUser:myPassword@myHost.com/myDb')
        check_map(map, 'myDb', 'myUser', 'myPassword', ['27017'], ['myHost'])
        # without user/password
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com/myDb')
        check_map(map, 'myDb', nil, nil, ['27017'], ['myHost'])
        # no db
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com')
        check_map(map, nil, nil, nil, ['27017'], ['myHost'])
      end

      it 'Two nodes' do
        # with ports
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myUser:myPassword@myHost.com:5432,myHost2.com:1234/myDb')
        check_map(map, 'myDb', 'myUser', 'myPassword', %w{5432 1234}, %w{myHost myHost2})
        # without ports
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myUser:myPassword@myHost.com:5432,myHost2.com/myDb')
        check_map(map, 'myDb', 'myUser', 'myPassword', %w{5432 27017}, %w{myHost myHost2})
        # without username/password
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com:5432,myHost2.com/myDb')
        check_map(map, 'myDb', nil, nil, %w{5432 27017}, %w{myHost myHost2})
        # no db
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com:5432,myHost2.com')
        check_map(map, nil, nil, nil, %w{5432 27017}, %w{myHost myHost2})
      end

      it 'Multiple nodes' do
        # with ports
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myUser:myPassword@myHost.com:5432,myHost2.com:1234,myHost3.com:4567/myDb')
        check_map(map, 'myDb', 'myUser', 'myPassword', %w{5432 1234 4567}, %w{myHost myHost2 myHost3})
        # without ports
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myUser:myPassword@myHost.com:5432,myHost2.com,myHost3.com:4567/myDb')
        check_map(map, 'myDb', 'myUser', 'myPassword', %w{5432 27017 4567}, %w{myHost myHost2 myHost3})
        # without username/password
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com:5432,myHost2.com,myHost3.com:4567/myDb')
        check_map(map, 'myDb', nil, nil, %w{5432 27017 4567}, %w{myHost myHost2 myHost3})
        # no db
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com:5432,myHost2.com,myHost3.com:4567')
        check_map(map, nil, nil, nil, %w{5432 27017 4567}, %w{myHost myHost2 myHost3})
      end

    end

  end # describe

end # module

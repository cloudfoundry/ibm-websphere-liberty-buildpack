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

      def check_server_xml_update_attribute(root, sm)
        contents = []
        contents << '<server>'
        contents << '<featureManager><feature>jsp-2.2</feature></featureManager>'
        t1 = "<mongo id='#{get_mongo_id}' libraryRef='myLibrary' password='noPassword' user='noUser' hostNames='noHost' ports='1111'/>"
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
          check_server_xml_update_element(root, sm)
          check_server_xml_update_attribute(root, sm)
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

        run_test(vcap_services, %w(myHost.com myHost2.com myHost3.net), %w(5432 27017 1234), env['MONGOHQ_URL'])
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
        expect(map['ports'].length).to eql(expected_ports.size)
        expected_ports.each_with_index do |value, index|
          expect(map['ports'][index]).to match(value)
        end
        expect(map['hosts'].length).to eql(expected_hosts.size)
        expected_hosts.each_with_index do |value, index|
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
        check_map(map, 'myDb', 'myUser', 'myPassword', %w(5432 1234), %w(myHost myHost2))
        # without ports
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myUser:myPassword@myHost.com:5432,myHost2.com/myDb')
        check_map(map, 'myDb', 'myUser', 'myPassword', %w(5432 27017), %w(myHost myHost2))
        # without username/password
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com:5432,myHost2.com/myDb')
        check_map(map, 'myDb', nil, nil, %w(5432 27017), %w(myHost myHost2))
        # no db
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com:5432,myHost2.com')
        check_map(map, nil, nil, nil, %w(5432 27017), %w(myHost myHost2))
      end

      it 'Multiple nodes' do
        # with ports
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myUser:myPassword@myHost.com:5432,myHost2.com:1234,myHost3.com:4567/myDb')
        check_map(map, 'myDb', 'myUser', 'myPassword', %w(5432 1234 4567), %w(myHost myHost2 myHost3))
        # without ports
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myUser:myPassword@myHost.com:5432,myHost2.com,myHost3.com:4567/myDb')
        check_map(map, 'myDb', 'myUser', 'myPassword', %w(5432 27017 4567), %w(myHost myHost2 myHost3))
        # without username/password
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com:5432,myHost2.com,myHost3.com:4567/myDb')
        check_map(map, 'myDb', nil, nil, %w(5432 27017 4567), %w(myHost myHost2 myHost3))
        # no db
        map = LibertyBuildpack::Services::Mongo.parse_url('mongodb://myHost.com:5432,myHost2.com,myHost3.com:4567')
        check_map(map, nil, nil, nil, %w(5432 27017 4567), %w(myHost myHost2 myHost3))
      end

    end

    describe 'MongoDB_2' do

      before do |example|
        # create hash containing vcap services data for a single instance.
        @vcap = {}
        @vcap['name'] = 'myMongo'
        @vcap['label'] = 'mongodb-2.2'
        @vcap['tags'] = %w(nosql document)
        @vcap['plan'] = 'free'
        creds = {}
        creds['hostname'] = '192.168.10.23'
        creds['host'] = '192.168.10.23'
        creds['port'] = 10_001
        creds['username'] = '485e460b-147f-4ae7-b5d3-bd15dd0f4046'
        creds['password'] = 'b15aac99-aef6-495f-96dd-53344c82fbf5'
        creds['name'] = '95381800-b0ca-4d95-9ac8-8cc536cdc803'
        creds['db'] = 'db'
        creds['url'] = 'mongodb://485e460b-147f-4ae7-b5d3-bd15dd0f4046:b15aac99-aef6-495f-96dd-53344c82fbf5@192.168.10.23:10001/db'
        @vcap['credentials'] = creds
        # Read the contents of the .yml config file. Use the actual file for most realistic coverage.
        file = File.join(File.expand_path('../../../lib/liberty_buildpack/services/config', File.dirname(__FILE__)), 'mongo.yml')
        @config = YAML.load_file(file)
        @driver_jars = ['db2.jar', get_lib_jar.to_s, 'mysql.jar']
      end

      #----------------------------------------------------------
      # Helper methods to return constants used in checking server.xml contents
      #----------------------------------------------------------
      def get_mongo_id
        'mongo-myMongo'
      end

      def get_mongodb_id
        'mongo-myMongo-db'
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

      def get_lib_jar
        'mongo-java-driver-2.13.3.jar'
      end

      def get_jndi
        'mongo/myMongo'
      end

      def get_host
        '${cloud.services.myMongo.connection.hosts}'
      end

      def get_port
        '${cloud.services.myMongo.connection.ports}'
      end

      def get_user
        '${cloud.services.myMongo.connection.user}'
      end

      def get_password
        '${cloud.services.myMongo.connection.password}'
      end

      def get_db
        '${cloud.services.myMongo.connection.db}'
      end

      #---------------------------------------------
      # Helper method that creates the Mongo object and calls parse_vcap_services. The runtime_vars.xml is not written to a file
      #---------------------------------------------
      def create_mongo
        runtime_vars_doc = REXML::Document.new('<server></server>')
        obj = Mongo.new('mongo', @config)
        obj.parse_vcap_services(runtime_vars_doc.root, @vcap)
        obj
      end

      #----------------------------------------------
      # Helper method that adds <featureManager> and <feature> into a REXML server.xml doc
      #----------------------------------------------
      def add_features(doc, features)
        fm = REXML::Element.new('featureManager', doc)
        features.each do |feature|
          f = REXML::Element.new('feature', fm)
          f.add_text(feature)
        end
      end

      #----------------------------------------------
      # Helper method that adds <application> or <webapplication> into a REXML server.xml doc
      #----------------------------------------------
      def add_application(doc, application_type, lib_id, api = nil)
        app = REXML::Element.new(application_type, doc)
        app.add_attribute('name', 'myapp')
        # Between lib_id and api visibility, only one can be set.
        if lib_id.nil? == false
          classloader_element = REXML::Element.new('classloader', app)
          classloader_element.add_attribute('commonLibraryRef', lib_id)
        end
        if api.nil? == false
          classloader_element = REXML::Element.new('classloader', app)
          classloader_element.add_attribute('apiTypeVisibility', api)
        end
      end

      #----------------------------------------------
      # Helper method that adds a mongo stanza into a REXML server.xml doc
      #----------------------------------------------
      def add_mongo(doc, id, lib_id, user, password, host, port)
        mongo = REXML::Element.new('mongo', doc)
        mongo.add_attribute('id', id)
        mongo.add_attribute('libraryRef', lib_id)
        if user.nil? == false
          mongo.add_attribute('user', user)
          mongo.add_attribute('password', password)
        end
        # add hostNames and ports elements.
        hosts = REXML::Element.new('hostNames', mongo)
        hosts.add_text(host)
        ports = REXML::Element.new('ports', mongo)
        ports.add_text(port)
      end

      #----------------------------------------------
      # Helper method that adds a mongoDB stanza into a REXML server.xml doc
      #----------------------------------------------
      def add_mongo_db(doc, mongo_db_id, db, jndi, mongo_id)
        mongodb = REXML::Element.new('mongoDB', doc)
        mongodb.add_attribute('id', mongo_db_id)
        mongodb.add_attribute('databaseName', db)
        mongodb.add_attribute('jndiName', jndi)
        mongodb.add_attribute('mongoRef', mongo_id)
      end

      #----------------------------------------------
      # Helper method that adds a library/fileset into a REXML server.xml doc
      #----------------------------------------------
      def add_fileset(doc, lib_id, fileset_id, dir, includes)
        library = REXML::Element.new('library', doc)
        library.add_attribute('id', lib_id)
        fileset = REXML::Element.new('fileset', library)
        fileset.add_attribute('id', fileset_id)
        fileset.add_attribute('dir', dir)
        fileset.add_attribute('includes', includes)
      end

      describe 'component dependencies' do
        it 'should indicate software to be installed' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            expect(obj.requires_liberty_extensions?).to eq(true)
            urls = {}
            # test that we return the url for the mongo client jar
            clients = obj.get_urls_for_client_jars([], urls)
            expect(clients.size).to eq(1)
            expect(clients[0]).to eq('https://repo1.maven.org/maven2/org/mongodb/mongo-java-driver/2.13.3/mongo-java-driver-2.13.3.jar')
            # test when user supplied client jar, return empty array
            clients = obj.get_urls_for_client_jars(['mongo-java-driver-2.11.3.jar'], urls)
            expect(clients.size).to eq(0)
            # no esas or zips to install
            components = LibertyBuildpack::Container::InstallComponents.new
            obj.get_required_esas(urls, components)
            zips = components.zips
            expect(zips.size).to eq(0)
            esas = components.esas
            expect(esas.size).to eq(0)
            features = Set.new
            obj.get_required_features(features)
            expect(features.to_a).to match_array(['mongodb-2.0'])
          end
        end # it
      end # describe component_dependencies

      describe 'create_mongo' do
        it 'should create a single Mongo configuration' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method.
            server_xml = File.join(root, 'server.xml')
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0'])
            add_application(server_xml_doc.root, 'application', nil)
            obj.create(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars)
            File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
            # create the Strings to check server.xml contents
            s1 = '<server>'
            s2 = '<featureManager><feature>servlet-3.0</feature><feature>mongodb-2.0</feature></featureManager>'
            s3 = "<application name='myapp'><classloader commonLibraryRef='#{get_lib_id}'/></application>"
            # The mongo stanza is logically split across two strings for readability, but needs to be checked as a single string.
            t1 = "<mongo id='#{get_mongo_id}' libraryRef='#{get_lib_id}' password='#{get_password}' user='#{get_user}'>"
            t2 = "<hostNames>#{get_host}</hostNames><ports>#{get_port}</ports></mongo>"
            s4 = t1 + t2
            s5 = "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='#{get_jndi}' mongoRef='#{get_mongo_id}'/>"
            s6 = "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}' includes='#{get_lib_jar}'/></library>"
            s7 = '</server>'
            expected = [s1, s2, s3, s4, s5, s6, s7]
            validate_xml(server_xml, expected)
          end
        end # it

        it 'should create a two Mongo configuration' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method. The server.xml will have a mongo instance already defined.
            server_xml = File.join(root, 'server.xml')
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0', 'mongodb-2.0'])
            add_application(server_xml_doc.root, 'application', get_lib_id)
            add_mongo(server_xml_doc.root, 'mongo-someMongo', 'mongo-library', 'someuser', 'somepassword', 'localhost', '6789')
            add_mongo_db(server_xml_doc.root, 'mongo-someMongo-db', 'somedb', 'somejndi', 'mongo-someMongo')
            add_fileset(server_xml_doc.root, get_lib_id, get_fileset_id, '${server.config.dir}/lib', get_lib_jar)
            obj.create(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars)
            File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
            # create the Strings to check server.xml contents
            s1 = '<server>'
            s2 = '<featureManager><feature>servlet-3.0</feature><feature>mongodb-2.0</feature></featureManager>'
            s3 = "<application name='myapp'><classloader commonLibraryRef='#{get_lib_id}'/></application>"
            # original mongo.
            t1 = "<mongo id='mongo-someMongo' libraryRef='#{get_lib_id}' password='somepassword' user='someuser'>"
            t2 = '<hostNames>localhost</hostNames><ports>6789</ports></mongo>'
            s4 = t1 + t2
            s5 = "<mongoDB databaseName='somedb' id='mongo-someMongo-db' jndiName='somejndi' mongoRef='mongo-someMongo'/>"
            s6 = "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}' includes='#{get_lib_jar}'/></library>"
            # The mongo stanza is logically split across two strings for readability, but needs to be checked as a single string.
            t1 = "<mongo id='#{get_mongo_id}' libraryRef='#{get_lib_id}' password='#{get_password}' user='#{get_user}'>"
            t2 = "<hostNames>#{get_host}</hostNames><ports>#{get_port}</ports></mongo>"
            s7 = t1 + t2
            s8 = "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='#{get_jndi}' mongoRef='#{get_mongo_id}'/>"
            s9 = '</server>'
            expected = [s1, s2, s3, s4, s5, s6, s7, s8, s9]
            validate_xml(server_xml, expected)
          end
        end # it
      end # describe create_mongo

      describe 'update_single_mongo' do
        it 'should update a local Mongo configuration to cloud' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method.
            server_xml = File.join(root, 'server.xml')
            server_xml_doc = REXML::Document.new('<server></server>')
            # test that we add the missing mongo feature
            add_features(server_xml_doc.root, ['servlet-3.0', 'mongodb-2.0'])
            add_application(server_xml_doc.root, 'application', get_lib_id)
            add_mongo(server_xml_doc.root, get_mongo_id, get_lib_id, 'someuser', 'somepassword', 'localhost', '6789')
            add_mongo_db(server_xml_doc.root, get_mongodb_id, 'somedb', 'somejndi', get_mongo_id)
            add_fileset(server_xml_doc.root, get_lib_id, get_fileset_id, '/home/drivers', 'some-mongo.jar')
            obj.update(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars, 1)
            File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
            # create the Strings to check server.xml contents
            s1 = '<server>'
            s2 = '<featureManager><feature>servlet-3.0</feature><feature>mongodb-2.0</feature></featureManager>'
            s3 = "<application name='myapp'><classloader commonLibraryRef='#{get_lib_id}'/></application>"
            # The mongo stanza is logically split across two strings for readability, but needs to be checked as a single string.
            t1 = "<mongo id='#{get_mongo_id}' libraryRef='#{get_lib_id}' password='#{get_password}' user='#{get_user}'>"
            t2 = "<hostNames>#{get_host}</hostNames><ports>#{get_port}</ports></mongo>"
            s4 = t1 + t2
            s5 = "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='somejndi' mongoRef='#{get_mongo_id}'/>"
            s6 = "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}' includes='#{get_lib_jar}'/></library>"
            s7 = '</server>'
            expected = [s1, s2, s3, s4, s5, s6, s7]
            validate_xml(server_xml, expected)
          end
        end # it

        it 'should update an unsecure local Mongo configuration to a secure cloud configuration' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method.
            server_xml = File.join(root, 'server.xml')
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0', 'mongodb-2.0'])
            # use webApplication in this variation
            add_application(server_xml_doc.root, 'webApplication', get_lib_id)
            add_mongo(server_xml_doc.root, get_mongo_id, get_lib_id, nil, nil, 'localhost', '6789')
            add_mongo_db(server_xml_doc.root, get_mongodb_id, 'somedb', 'somejndi', get_mongo_id)
            add_fileset(server_xml_doc.root, get_lib_id, get_fileset_id, '/home/drivers', 'some-mongo.jar')
            obj.update(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars, 1)
            File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
            # create the Strings to check server.xml contents
            s1 = '<server>'
            s2 = '<featureManager><feature>servlet-3.0</feature><feature>mongodb-2.0</feature></featureManager>'
            s3 = "<webApplication name='myapp'><classloader commonLibraryRef='#{get_lib_id}'/></webApplication>"
            # The mongo stanza is logically split across two strings for readability, but needs to be checked as a single string.
            t1 = "<mongo id='#{get_mongo_id}' libraryRef='#{get_lib_id}' password='#{get_password}' user='#{get_user}'>"
            t2 = "<hostNames>#{get_host}</hostNames><ports>#{get_port}</ports></mongo>"
            s4 = t1 + t2
            s5 = "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='somejndi' mongoRef='#{get_mongo_id}'/>"
            s6 = "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}' includes='#{get_lib_jar}'/></library>"
            s7 = '</server>'
            expected = [s1, s2, s3, s4, s5, s6, s7]
            validate_xml(server_xml, expected)
          end
        end # it

        it 'should ignore config ids when updating a single mongo configuration' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method.
            server_xml = File.join(root, 'server.xml')
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0', 'mongodb-2.0'])
            # use webApplication in this variation
            add_application(server_xml_doc.root, 'webApplication', 'fake_lib')
            add_mongo(server_xml_doc.root, 'fake_mongo', 'fake_lib', nil, nil, 'localhost', '6789')
            add_mongo_db(server_xml_doc.root, 'fake_mongo_db', 'somedb', 'somejndi', 'fake_mongo')
            add_fileset(server_xml_doc.root, 'fake_lib', get_fileset_id, '/home/drivers', get_lib_jar)
            obj.update(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars, 1)
            File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
            # create the Strings to check server.xml contents
            s1 = '<server>'
            s2 = '<featureManager><feature>servlet-3.0</feature><feature>mongodb-2.0</feature></featureManager>'
            s3 = "<webApplication name='myapp'><classloader commonLibraryRef='fake_lib'/></webApplication>"
            # The mongo stanza is logically split across two strings for readability, but needs to be checked as a single string.
            t1 = "<mongo id='fake_mongo' libraryRef='fake_lib' password='#{get_password}' user='#{get_user}'>"
            t2 = "<hostNames>#{get_host}</hostNames><ports>#{get_port}</ports></mongo>"
            s4 = t1 + t2
            s5 = "<mongoDB databaseName='#{get_db}' id='fake_mongo_db' jndiName='somejndi' mongoRef='fake_mongo'/>"
            s6 = "<library id='fake_lib'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}' includes='#{get_lib_jar}'/></library>"
            s7 = '</server>'
            expected = [s1, s2, s3, s4, s5, s6, s7]
            validate_xml(server_xml, expected)
          end
        end # it

        it 'should create the configuration if missing from provided server.xml' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method.
            server_xml = File.join(root, 'server.xml')
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0'])
            # use webApplication in this variation
            add_application(server_xml_doc.root, 'webApplication', nil)
            obj.update(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars, 1)
            File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
            # create the Strings to check server.xml contents
            s1 = '<server>'
            s2 = '<featureManager><feature>servlet-3.0</feature><feature>mongodb-2.0</feature></featureManager>'
            s3 = "<webApplication name='myapp'><classloader commonLibraryRef='#{get_lib_id}'/></webApplication>"
            # The mongo stanza is logically split across two strings for readability, but needs to be checked as a single string.
            t1 = "<mongo id='#{get_mongo_id}' libraryRef='#{get_lib_id}' password='#{get_password}' user='#{get_user}'>"
            t2 = "<hostNames>#{get_host}</hostNames><ports>#{get_port}</ports></mongo>"
            s4 = t1 + t2
            s5 = "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='#{get_jndi}' mongoRef='#{get_mongo_id}'/>"
            s6 = "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}' includes='#{get_lib_jar}'/></library>"
            s7 = '</server>'
            expected = [s1, s2, s3, s4, s5, s6, s7]
            validate_xml(server_xml, expected)
          end
        end # it

        it 'should create the shared lib with api visibility when configuration if missing from provided server.xml' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method.
            server_xml = File.join(root, 'server.xml')
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0', 'mongodb-2.0'])
            # use webApplication in this variation
            add_application(server_xml_doc.root, 'webApplication', nil, 'spec,ibm-api,api,third-party')
            obj.update(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars, 1)
            File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
            # create the Strings to check server.xml contents
            s1 = '<server>'
            s2 = '<featureManager><feature>servlet-3.0</feature><feature>mongodb-2.0</feature></featureManager>'
            s3 = "<webApplication name='myapp'><classloader apiTypeVisibility='spec,ibm-api,api,third-party' commonLibraryRef='#{get_lib_id}'/></webApplication>"
            # The mongo stanza is logically split across two strings for readability, but needs to be checked as a single string.
            t1 = "<mongo id='#{get_mongo_id}' libraryRef='#{get_lib_id}' password='#{get_password}' user='#{get_user}'>"
            t2 = "<hostNames>#{get_host}</hostNames><ports>#{get_port}</ports></mongo>"
            s4 = t1 + t2
            s5 = "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='#{get_jndi}' mongoRef='#{get_mongo_id}'/>"
            s6 = "<library apiTypeVisibility='spec,ibm-api,api,third-party' id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}' includes='#{get_lib_jar}'/></library>"
            s7 = '</server>'
            expected = [s1, s2, s3, s4, s5, s6, s7]
            validate_xml(server_xml, expected)
          end
        end # it

        it 'should detect missing library when updating a Mongo configuration' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0', 'mongodb-2.0'])
            add_application(server_xml_doc.root, 'application', get_lib_id)
            add_mongo(server_xml_doc.root, get_mongo_id, get_lib_id, 'otheruser', 'otherpassword', 'server', '1234')
            add_mongo_db(server_xml_doc.root, get_mongodb_id, 'somedb', 'otherjndi', get_mongo_id)
            expect { obj.update(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars, 1) }.to raise_error(RuntimeError, 'The configuration for mongo myMongo does not contain a library')
          end
        end # it
      end # describe update_single_mongo

      describe 'update two mongo configuration' do
        it 'should update a two Mongo configuration' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method. The server.xml will have a mongo instance already defined.
            server_xml = File.join(root, 'server.xml')
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0', 'mongodb-2.0'])
            add_application(server_xml_doc.root, 'application', get_lib_id)
            add_mongo(server_xml_doc.root, 'mongo-someMongo', 'mongo-library', 'someuser', 'somepassword', 'localhost', '6789')
            add_mongo_db(server_xml_doc.root, 'mongo-someMongo-db', 'somedb', 'somejndi', 'mongo-someMongo')
            add_mongo(server_xml_doc.root, get_mongo_id, get_lib_id, 'otheruser', 'otherpassword', 'server', '1234')
            add_mongo_db(server_xml_doc.root, get_mongodb_id, 'somedb', 'otherjndi', get_mongo_id)
            add_fileset(server_xml_doc.root, get_lib_id, get_fileset_id, '${server.config.dir}/lib', 'mongo-2.10.1.jar')
            obj.update(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars, 2)
            File.open(server_xml, 'w') { |file| server_xml_doc.write(file) }
            # create the Strings to check server.xml contents
            s1 = '<server>'
            s2 = '<featureManager><feature>servlet-3.0</feature><feature>mongodb-2.0</feature></featureManager>'
            s3 = "<application name='myapp'><classloader commonLibraryRef='#{get_lib_id}'/></application>"
            # original mongo.
            t1 = "<mongo id='mongo-someMongo' libraryRef='#{get_lib_id}' password='somepassword' user='someuser'>"
            t2 = '<hostNames>localhost</hostNames><ports>6789</ports></mongo>'
            s4 = t1 + t2
            s5 = "<mongoDB databaseName='somedb' id='mongo-someMongo-db' jndiName='somejndi' mongoRef='mongo-someMongo'/>"
            s6 = "<library id='#{get_lib_id}'><fileset dir='#{get_lib_dir}' id='#{get_fileset_id}' includes='#{get_lib_jar}'/></library>"
            # The mongo stanza is logically split across two strings for readability, but needs to be checked as a single string.
            t1 = "<mongo id='#{get_mongo_id}' libraryRef='#{get_lib_id}' password='#{get_password}' user='#{get_user}'>"
            t2 = "<hostNames>#{get_host}</hostNames><ports>#{get_port}</ports></mongo>"
            s7 = t1 + t2
            s8 = "<mongoDB databaseName='#{get_db}' id='#{get_mongodb_id}' jndiName='otherjndi' mongoRef='#{get_mongo_id}'/>"
            s9 = '</server>'
            expected = [s1, s2, s3, s4, s5, s6, s7, s8, s9]
            validate_xml(server_xml, expected)
          end
        end # it

        it 'should detect wrong mongo config id when updating a two Mongo configuration' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method. The server.xml will have a mongo instance already defined.
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0', 'mongodb-2.0'])
            add_application(server_xml_doc.root, 'application', get_lib_id)
            add_mongo(server_xml_doc.root, 'mongo-someMongo', 'mongo-library', 'someuser', 'somepassword', 'localhost', '6789')
            add_mongo_db(server_xml_doc.root, 'mongo-someMongo-db', 'somedb', 'somejndi', 'mongo-someMongo')
            add_mongo(server_xml_doc.root, 'wrong_mongo_id', get_lib_id, 'otheruser', 'otherpassword', 'server', '1234')
            add_mongo_db(server_xml_doc.root, get_mongodb_id, 'somedb', 'otherjndi', get_mongo_id)
            add_fileset(server_xml_doc.root, get_lib_id, get_fileset_id, '${server.config.dir}/lib', 'mongo-2.10.1.jar')
            expect { obj.update(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars, 2) }.to raise_error(RuntimeError, 'required mongo configuration for service myMongo is missing')
          end
        end # it

        it 'should detect wrong mongoDB config id when updating a two Mongo configuration' do
          Dir.mktmpdir do |root|
            obj = create_mongo
            # create a server.xml to pass to the create method. The server.xml will have a mongo instance already defined.
            server_xml_doc = REXML::Document.new('<server></server>')
            add_features(server_xml_doc.root, ['servlet-3.0', 'mongodb-2.0'])
            add_application(server_xml_doc.root, 'application', get_lib_id)
            add_mongo(server_xml_doc.root, 'mongo-someMongo', 'mongo-library', 'someuser', 'somepassword', 'localhost', '6789')
            add_mongo_db(server_xml_doc.root, 'mongo-someMongo-db', 'somedb', 'somejndi', 'mongo-someMongo')
            add_mongo(server_xml_doc.root, get_mongo_id, get_lib_id, 'otheruser', 'otherpassword', 'server', '1234')
            add_mongo_db(server_xml_doc.root, 'wrong_mongoDB_id', 'somedb', 'otherjndi', get_mongo_id)
            add_fileset(server_xml_doc.root, get_lib_id, get_fileset_id, '${server.config.dir}/lib', 'mongo-2.10.1.jar')
            expect { obj.update(server_xml_doc.root, root, '${server.config.dir}/lib', @driver_jars, 2) }.to raise_error(RuntimeError, 'required mongoDB configuration for service myMongo is missing')
          end
        end # it
      end # describe update_two_mongo_configuration

    end
  end
end # module

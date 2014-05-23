# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013 the original author or authors.
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
require 'liberty_buildpack/container/liberty'
require 'liberty_buildpack/container/container_utils'

module LibertyBuildpack::Container

  describe Liberty do

    LIBERTY_VERSION = LibertyBuildpack::Util::TokenizedVersion.new('8.5.5')
    LIBERTY_SINGLE_DOWNLOAD_URI = 'test-liberty-uri.tar.gz'.freeze # end of URI (here ".tar.gz") is significant in liberty container code
    LIBERTY_DETAILS = [LIBERTY_VERSION, LIBERTY_SINGLE_DOWNLOAD_URI, 'spec/fixtures/license.html']
    DISABLE_2PC_JAVA_OPT_REGEX = '-Dcom.ibm.tx.jta.disable2PC=true'.freeze

    let(:application_cache) { double('ApplicationCache') }
    let(:component_index) { double('ComponentIndex') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
      # return license file by default
      application_cache.stub(:get).and_yield(File.open('spec/fixtures/license.html'))
    end

    after do
      $stdout = STDOUT
      $stderr = STDERR
    end

    describe 'prepare applications' do
      it 'should extract all applications' do
        Dir.mktmpdir do |root|
          app_dir = File.join(root, 'spec/fixtures/container_liberty_extract')
          Liberty.new(
          app_dir: app_dir,
          configuration: {},
          java_home: '',
          java_opts: [],
          license_ids: {}
          )

          apps = Dir.glob(File.join(app_dir, '*'))
          apps.each { |file| expect(File.directory? file).to be_true }
        end
      end
    end

    describe 'detect' do
      it 'should detect WEB-INF' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)
        detected = Liberty.new(
        app_dir: 'spec/fixtures/container_liberty',
        configuration: {},
        java_home: '',
        java_opts: [],
        license_ids: {}
        ).detect

        expect(detected).to include('liberty-8.5.5')
      end

      it 'should detect META-INF' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)
        detected = Liberty.new(
        app_dir: 'spec/fixtures/container_liberty_ear',
        configuration: {},
        java_home: '',
        java_opts: [],
        license_ids: {}
        ).detect

        expect(detected).to include('liberty-8.5.5')
      end

      it 'should detect server.xml for a zipped up server configuration' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)
        detected = Liberty.new(
        app_dir: 'spec/fixtures/container_liberty_server',
        configuration: {},
        java_home: '',
        java_opts: [],
        license_ids: {}
        ).detect

        expect(detected).to include('liberty-8.5.5')
      end

      it 'should detect server.xml for a single server push' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)
        detected = Liberty.new(
        app_dir: 'spec/fixtures/container_liberty_single_server',
        configuration: {},
        java_home: '',
        java_opts: [],
        license_ids: {}
        ).detect

        expect(detected).to include('liberty-8.5.5')
      end

      it 'should throw an error when a server including binaries was pushed' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        expect do
          Liberty.new(
          app_dir: 'spec/fixtures/failed-package',
          configuration: {},
          java_home: '',
          java_opts: [],
          license_ids: {}
          ).detect
        end.to raise_error(/Pushed\ a\ wrongly\ packaged\ server\ please\ use\ 'server\ package --include=usr'\ to\ package\ a\ server/)
      end

      it 'should throw an error when there are multiple server.xmls' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write('<httpEndpoint id="defaultHttpEndpoint" host="*" httpPort="9080" httpsPort="9443" />')
          end

          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'otherServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'otherServer', 'server.xml'), 'w') do |file|
            file.write('<httpEndpoint id="defaultHttpEndpoint" host="*" httpPort="9080" httpsPort="9443" />')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          expect do
            Liberty.new(
            app_dir: root,
            configuration: {},
            java_home: '',
            java_opts: [],
            license_ids: {}
            ).detect
          end.to raise_error(/Incorrect\ number\ of\ servers\ to\ deploy/)
        end # mktmpdir
      end # it

      it 'should not detect when WEB-INF and META-INF and server.xml are absent' do
        detected = Liberty.new(
        app_dir: 'spec/fixtures/container_main',
        configuration: {},
        java_home: '',
        java_opts: [],
        license_ids: {}
        ).detect

        expect(detected).to be_nil
      end

      it 'should not detect when a jar file is pushed' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)
        detected = Liberty.new(
        app_dir: 'spec/fixtures/jar_file',
        configuration: {},
        java_home: '',
        java_opts: [],
        license_ids: {}
        ).detect

        expect(detected).to be_nil
      end
    end

    describe 'compile' do
      it 'should fail if license ids do not match' do
        Dir.mktmpdir do |root|
          Dir.mkdir File.join(root, 'WEB-INF')

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          expect do
            Liberty.new(
              app_dir: root,
              lib_directory: '',
              configuration: {},
              environment: {},
              license_ids: { 'IBM_LIBERTY_LICENSE' => 'Incorrect' }
            ).compile
          end.to raise_error
        end
      end

      it 'should extract Liberty from a TAR file' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'WEB-INF')

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          liberty_dir = File.join root, '.liberty'
          bin_dir = File.join liberty_dir, 'bin'
          default_server_xml = File.join liberty_dir, 'templates', 'servers', 'defaultServer', 'server.xml'
          rest_connector = File.join liberty_dir, 'clients', 'restConnector.jar'

          expect(File.exists?(File.join bin_dir, 'server')).to be_true
          expect(File.exists?(File.join bin_dir, 'featureManager')).to be_true
          expect(File.exists?(File.join bin_dir, 'securityUtility')).to be_true
          expect(File.exists?(File.join bin_dir, 'productInfo')).to be_true
          expect(File.exists?(default_server_xml)).to be_true
          expect(File.exists?(rest_connector)).to be_true

          icap_properties = File.join liberty_dir, 'etc', 'extensions', 'icap.properties'
          expect(File.exists?(icap_properties)).to be_true
          icap_properties_content = File.read icap_properties
          expect(icap_properties_content.include? 'productInstall=.liberty/icap').to be_true
        end
      end

      it 'should extract Liberty from a JAR file' do
        Dir.mktmpdir do |root|
          Dir.mkdir File.join(root, 'WEB-INF')

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => 'wlp-developers.jar' })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with('wlp-developers.jar').and_yield(File.open('spec/fixtures/wlp-stub.jar'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          liberty_dir = File.join root, '.liberty'
          bin_dir = File.join liberty_dir, 'bin'
          default_server_xml = File.join liberty_dir, 'templates', 'servers', 'defaultServer', 'server.xml'
          rest_connector = File.join liberty_dir, 'clients', 'restConnector.jar'

          expect(File.exists?(File.join bin_dir, 'server')).to be_true
          expect(File.exists?(File.join bin_dir, 'featureManager')).to be_true
          expect(File.exists?(File.join bin_dir, 'securityUtility')).to be_true
          expect(File.exists?(File.join bin_dir, 'productInfo')).to be_true
          expect(File.exists?(default_server_xml)).to be_true
          expect(File.exists?(rest_connector)).to be_true
        end
      end

      it 'should handle all-in-one as Liberty core' do
        Dir.mktmpdir do |root|
          Dir.mkdir File.join(root, 'WEB-INF')

          LIBERTY_OS_DETAILS = [LIBERTY_VERSION, 'wlp-developers.jar', 'spec/fixtures/license.html']

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_OS_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with('wlp-developers.jar').and_yield(File.open('spec/fixtures/wlp-stub.jar'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          liberty_dir = File.join root, '.liberty'
          bin_dir = File.join liberty_dir, 'bin'
          default_server_xml = File.join liberty_dir, 'templates', 'servers', 'defaultServer', 'server.xml'
          rest_connector = File.join liberty_dir, 'clients', 'restConnector.jar'

          expect(File.exists?(File.join bin_dir, 'server')).to be_true
          expect(File.exists?(File.join bin_dir, 'featureManager')).to be_true
          expect(File.exists?(File.join bin_dir, 'securityUtility')).to be_true
          expect(File.exists?(File.join bin_dir, 'productInfo')).to be_true
          expect(File.exists?(default_server_xml)).to be_true
          expect(File.exists?(rest_connector)).to be_true
        end
      end

      it 'should find and copy .java-overlay included in WAR file or server directory during push' do
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p File.join(root, 'WEB-INF')
          FileUtils.mkdir_p File.join(root, '.java')
          FileUtils.mkdir_p File.join(root, 'resources', '.java-overlay', '.java')
          File.open(File.join(root, 'resources', '.java-overlay', '.java', 'overlay.txt'), 'w') do |file|
            file.write('overlay file')
          end
          File.open(File.join(root, '.java', 'test.txt'), 'w') do |file|
            file.write('test file that should still exist after overlay')
          end

          LIBERTY_OS_DETAILS = [LIBERTY_VERSION, 'wlp-developers.jar', 'spec/fixtures/license.html']

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
           .and_return(LIBERTY_OS_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
           application_cache.stub(:get).with('wlp-developers.jar').and_yield(File.open('spec/fixtures/wlp-stub.jar'))

          Liberty.new(
          app_dir: root,
          lib_directory: '',
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          expect(File.exists?(File.join root, '.java', 'overlay.txt')).to be_true
          expect(File.exists?(File.join root, '.java', 'test.txt')).to be_true
        end
      end

      it 'should find and copy .java-overlay included in server zip package during push' do
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p File.join(root, '.java')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'server1', 'resources', '.java-overlay', '.java')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'server1', 'server.xml'), 'w') do |file|
            file.write('<httpEndpoint id="defaultHttpEndpoint" host="*" httpPort="9080" httpsPort="9443" />')
          end
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'server1', 'resources', '.java-overlay', '.java', 'overlay.txt'), 'w') do |file|
            file.write('overlay file')
          end
          File.open(File.join(root, '.java', 'test.txt'), 'w') do |file|
            file.write('test file that should still exist after overlay')
          end

          LIBERTY_OS_DETAILS = [LIBERTY_VERSION, 'wlp-developers.jar', 'spec/fixtures/license.html']

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
           .and_return(LIBERTY_OS_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
           application_cache.stub(:get).with('wlp-developers.jar').and_yield(File.open('spec/fixtures/wlp-stub.jar'))

          Liberty.new(
          app_dir: root,
          lib_directory: '',
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          expect(File.exists?(File.join root, '.java', 'overlay.txt')).to be_true
          expect(File.exists?(File.join root, '.java', 'test.txt')).to be_true
        end
      end

      it 'should make the ./bin/server script runnable for the zipped up server case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)
        LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
        component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })
        LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write('your text')
          end
          app_dir = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'apps')
          FileUtils.mkdir_p(app_dir)
          stub_war_file = File.join('spec', 'fixtures', 'stub-spring.war')
          war_file = File.join(app_dir, 'test.war')
          FileUtils.cp(stub_war_file, war_file)

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          server_script = File.join(root, '.liberty', 'bin', 'server')
          expect(File.exists?(server_script)).to be_true
          expect(File.executable?(server_script)).to be_true
          expect(File.directory? war_file).to be_true
        end
      end

      it 'should make the ./bin/server script runnable for the WEB-INF case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)
        LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
        component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })
        LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'WEB-INF')
          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)

          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          server_script = File.join(root, '.liberty', 'bin', 'server')
          expect(File.executable?(server_script)).to be_true
        end
      end

      it 'should make the ./bin/server script runnable for the META-INF case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)
        LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
        component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })
        LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'META-INF')
          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)

          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          server_script = File.join(root, '.liberty', 'bin', 'server')
          expect(File.executable?(server_script)).to be_true
        end
      end

      it 'should produce the correct server.xml for the WEB-INF case when the app is of type war' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'WEB-INF')

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile
          server_xml_file = File.join root, '.liberty', 'usr', 'servers', 'defaultServer', 'server.xml'
          expect(File.exists?(server_xml_file)).to be_true

          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents.include? '<featureManager>').to be_true
          expect(server_xml_contents.include? '<application context-root="/" location="myapp" name="myapp"').to be_true
          expect(server_xml_contents.include? 'type="war"').to be_true
          expect(server_xml_contents.include? 'httpPort="${port}"').to be_true
          expect(server_xml_contents.include? '<httpDispatcher enableWelcomePage="false"/>').to be_true
        end
      end

      it 'should produce droplet.yaml for WEB-INF case' do
        Dir.mktmpdir do |root|
          droplet_yaml_file = File.join root, 'droplet.yaml'
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'WEB-INF')
          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          expect(File.exists?(droplet_yaml_file)).to be_true

          droplet_yaml_content = YAML.load(File.read droplet_yaml_file)
          expect(droplet_yaml_content).to have_key('state_file')
          expect(droplet_yaml_content['state_file']).to eq('app/.liberty.state')
        end
      end

      it 'should NOT produce droplet.yaml for WEB-INF case when there is no icap extensions' do
        Dir.mktmpdir do |root|
          droplet_yaml_file = File.join root, 'droplet.yaml'
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'WEB-INF')
          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub-no-icap.tar.gz'))

          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          expect(File.exists?(droplet_yaml_file)).to be_false
        end
      end

      it 'should produce the correct server.xml for the META-INF case when the app is of type ear' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'META-INF')

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile
          server_xml_file = File.join root, '.liberty', 'usr', 'servers', 'defaultServer', 'server.xml'
          expect(File.exists?(server_xml_file)).to be_true

          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents.include? '<featureManager>').to be_true
          expect(server_xml_contents.include? '<application context-root="/" location="myapp" name="myapp"').to be_true
          expect(server_xml_contents.include? 'type="ear"').to be_true
          expect(server_xml_contents.include? 'httpPort="${port}"').to be_true
        end
      end

      it 'should produce the correct results for the zipped-up server configuration' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write('your text')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
          app_dir: root,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          liberty_directory = File.join(root, '.liberty')
          expect(Dir.exists?(liberty_directory)).to be_true

          server_command = File.join(root, '.liberty', 'bin', 'server')
          expect(File.exists?(server_command)).to be_true

          license_files = File.join(root, '.liberty', 'lafiles')
          expect(Dir.exists?(license_files)).to be_true

          usr_directory = File.join(root, '.liberty', 'usr')
          expect(File.symlink?(usr_directory)).to be_true
          expect(File.readlink(usr_directory)).to eq('../wlp/usr')
        end

      end

      it 'should copy internal user esa files for a pushed server scenario' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write('your text')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub-dummy-user-esa.tgz'))

          Liberty.new(
          app_dir: root,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          feature_lib_dir = File.join(root, '.liberty', 'usr', 'extension', 'lib')
          expect(Dir.exists?(feature_lib_dir)).to be_true
          jar_file = File.join(feature_lib_dir, 'dummy_feature.jar')
          expect(File.exists?(jar_file)).to be_true
          mf_dir = File.join(feature_lib_dir, 'features')
          expect(Dir.exists?(mf_dir)).to be_true
          mf_file = File.join(mf_dir, 'dummy_feature.mf')
          expect(File.exists?(mf_file)).to be_true
        end
      end

      it 'should copy internal user esa files for a pushed server scenario when pushed server contains another user esa' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write('your text')
          end
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'extension', 'lib')
          File.open(File.join(root, 'wlp', 'usr', 'extension', 'lib', 'existing.jar'), 'w') do |file|
            file.write('some text')
          end
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'extension', 'lib', 'features')
          File.open(File.join(root, 'wlp', 'usr', 'extension', 'lib', 'features', 'existing.mf'), 'w') do |file|
            file.write('other text')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub-dummy-user-esa.tgz'))

          Liberty.new(
          app_dir: root,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          feature_lib_dir = File.join(root, '.liberty', 'usr', 'extension', 'lib')
          expect(Dir.exists?(feature_lib_dir)).to be_true
          jar_file = File.join(feature_lib_dir, 'dummy_feature.jar')
          expect(File.exists?(jar_file)).to be_true
          jar_file = File.join(feature_lib_dir, 'existing.jar')
          expect(File.exists?(jar_file)).to be_true
          mf_dir = File.join(feature_lib_dir, 'features')
          expect(Dir.exists?(mf_dir)).to be_true
          mf_file = File.join(mf_dir, 'dummy_feature.mf')
          expect(File.exists?(mf_file)).to be_true
          mf_file = File.join(mf_dir, 'existing.mf')
          expect(File.exists?(mf_file)).to be_true
        end
      end

      it 'should produce the correct results for single server configuration' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p root
          File.open(File.join(root, 'server.xml'), 'w') do |file|
            file.write("<server><httpEndpoint id=\"defaultHttpEndpoint\" host=\"*\" httpPort=\"9080\" httpsPort=\"9443\" /></server>")
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
          app_dir: root,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          liberty_directory = File.join(root, '.liberty')
          expect(Dir.exists?(liberty_directory)).to be_true

          server_command = File.join(root, '.liberty', 'bin', 'server')
          expect(File.exists?(server_command)).to be_true

          license_files = File.join(root, '.liberty', 'lafiles')
          expect(Dir.exists?(license_files)).to be_true

          default_server_directory = File.join(root, '.liberty', 'usr', 'servers', 'defaultServers')
          expect(Dir.exists?(default_server_directory))

          usr_symlink = File.join(root, '.liberty', 'usr', 'servers', 'defaultServer', 'server.xml')
          expect(File.symlink?(usr_symlink)).to be_true
          expect(File.readlink(usr_symlink)).to eq(Pathname.new(File.join(root, 'server.xml')).relative_path_from(Pathname.new(default_server_directory)).to_s)

          server_xml_file = File.join root, '.liberty', 'usr', 'servers', 'defaultServer', 'server.xml'
          expect(File.exists?(server_xml_file)).to be_true

          server_xml_contents = File.read(server_xml_file)
          endpoints = REXML::XPath.match(REXML::Document.new(server_xml_contents), '/server/httpEndpoint')
          expect(endpoints.size).to eq(1)
          attributes = endpoints[0].attributes
          expect(attributes).to have_key('httpPort')
          expect(attributes).not_to have_key('httpsPort')
          expect(attributes).to have_key('host')
        end
      end

      it 'should add an http endpoint if missing' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p root
          File.open(File.join(root, 'server.xml'), 'w') do |file|
            file.write('<server></server>')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
          app_dir: root,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          server_xml_file = File.join root, '.liberty', 'usr', 'servers', 'defaultServer', 'server.xml'
          server_xml_contents = File.read(server_xml_file)
          endpoints = REXML::XPath.match(REXML::Document.new(server_xml_contents), '/server/httpEndpoint')
          expect(endpoints.size).to eq(1)
          attributes = endpoints[0].attributes
          expect(attributes).to have_key('httpPort')
          expect(attributes).not_to have_key('httpsPort')
          expect(attributes).to have_key('host')
        end
      end

      it 'should only have one http endpoint' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p root
          File.open(File.join(root, 'server.xml'), 'w') do |file|
            file.write('<server>')
            file.write('<httpEndpoint id="defaultHttpEndpoint" host="*" httpPort="9080" httpsPort="9443" />')
            file.write('<httpEndpoint id="defaultHttpEndpoint2" host="*" httpPort="9080" httpsPort="9443" />')
            file.write('<httpEndpoint id="defaultHttpEndpoint3" host="*" httpPort="9080" httpsPort="9443" />')
            file.write('</server>')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
          app_dir: root,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          server_xml_file = File.join root, '.liberty', 'usr', 'servers', 'defaultServer', 'server.xml'
          server_xml_contents = File.read(server_xml_file)
          endpoints = REXML::XPath.match(REXML::Document.new(server_xml_contents), '/server/httpEndpoint')
          expect(endpoints.size).to eq(1)
          attributes = endpoints[0].attributes
          expect(attributes).to have_key('httpPort')
          expect(attributes).not_to have_key('httpsPort')
          expect(attributes).to have_key('host')
        end
      end

      it 'should modify server xml to work with cloud foundry' do
        Dir.mktmpdir do |root|
          droplet_yaml_file = File.join root, 'droplet.yaml'
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write("<server><httpEndpoint id=\"defaultHttpEndpoint\" host=\"localhost\" httpPort=\"9080\" httpsPort=\"9443\" /></server>")
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
          app_dir: root,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          liberty_directory = File.join(root, '.liberty')
          expect(Dir.exists?(liberty_directory)).to be_true

          server_xml_file = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read server_xml_file
          expect(server_xml_contents.include? 'host="*"').to be_true
          expect(server_xml_contents.include? 'httpPort="${port}"').to be_true
          expect(server_xml_contents.include? 'httpsPort=').to be_false
          expect(server_xml_contents).to match(/<webContainer extractHostHeaderPort='true' trustHostHeaderPort='true'\/>/)
          expect(File.exists?(droplet_yaml_file)).to be_false
        end
      end

      it 'should update webContainer element if server.xml already contains one' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write("<server><webContainer extractHostHeaderPort='false' trusted='false' /></server>")
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
          app_dir: root,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          liberty_directory = File.join(root, '.liberty')
          expect(Dir.exists?(liberty_directory)).to be_true

          server_xml_file = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read server_xml_file
          expect(server_xml_contents).to match(/<webContainer extractHostHeaderPort="true" trustHostHeaderPort="true" trusted="false"\/>/)
        end
      end

      it 'should add droplet.yaml when server xml contains myapp application' do
        Dir.mktmpdir do |root|
          droplet_yaml_file = File.join root, 'droplet.yaml'
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write("<server><httpEndpoint id=\"defaultHttpEndpoint\" host=\"localhost\" httpPort=\"9080\" httpsPort=\"9443\" /><application name=\"myapp\" /></server>")
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
            .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
            app_dir: root,
            configuration: {},
            environment: {},
            license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          liberty_directory = File.join root, '.liberty'
          expect(Dir.exists?(liberty_directory)).to be_true

          server_xml_file = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents.include? '<feature>icap:appstate-1.0</feature>').to be_true
          expect(server_xml_contents.include? "<icap_appstate appName='myapp' markerPath='${home}/.liberty.state'").to be_true
          expect(server_xml_contents.include? "<httpDispatcher enableWelcomePage='false'/>").to be_true

          expect(File.exists?(droplet_yaml_file)).to be_true
        end
      end

      it 'should raise an exception when the repository cannot be found' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'WEB-INF')

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          expect do
            Liberty.new(
            app_dir: root,
            lib_directory: library_directory,
            configuration: {},
            environment: {},
            license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
            ).compile
          end.to raise_error(RuntimeError, 'Failed to locate a repository containing a component_index and installable components using uri test-liberty-uri.tar.gz.')
        end
      end
    end

    describe 'release' do
      it 'should generate a jvm.options file if one is not provided in server package case' do
        Dir.mktmpdir do |root|
          liberty_home = File.join(root, '.liberty')
          FileUtils.mkdir_p liberty_home
          FileUtils.ln_sf(Pathname.new(File.join(root, 'wlp', 'usr')).relative_path_from(Pathname.new(liberty_home)), liberty_home)
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'anyServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'anyServer', 'server.xml'), 'w') do |file|
            file.write('your text')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.jar'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          java_opts: %w(test-opt-2 test-opt-1),
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).release

          jvm_options_file = File.join(root, 'wlp', 'usr', 'servers', 'anyServer', 'jvm.options')
          expect(File.exists?(jvm_options_file)).to be_true
          file_contents = File.read(jvm_options_file)
          expect(file_contents).to match(/test-opt-1/)
          expect(file_contents).to match(/test-opt-2/)
          expect(file_contents).to match(DISABLE_2PC_JAVA_OPT_REGEX)
        end
      end

      it 'should generate a jvm.options file if one is not provided in server directory case' do
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p File.join(root, '.liberty', 'usr', 'servers', 'defaultServer')
          File.open(File.join(root, 'server.xml'), 'w') do |file|
            file.write('your text')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.jar'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          java_opts: %w(test-opt-2 test-opt-1),
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).release

          jvm_options_file = File.join(root, 'jvm.options')
          expect(File.exists?(jvm_options_file)).to be_true
          expect(File.read(jvm_options_file)).to match(/test-opt-1/)

          jvm_options_file = File.join(root, '.liberty', 'usr', 'servers', 'defaultServer', 'jvm.options')
          expect(File.exists?(jvm_options_file)).to be_true
          file_contents = File.read(jvm_options_file)
          expect(file_contents).to match(/test-opt-1/)
          expect(file_contents).to match(/test-opt-2/)
          expect(file_contents).to match(DISABLE_2PC_JAVA_OPT_REGEX)
        end
      end

      it 'should use jvm.options file if one is provided in server package case.' do
        Dir.mktmpdir do |root|
          Dir.mkdir File.join(root, 'WEB-INF')
          liberty_home = File.join(root, '.liberty')
          FileUtils.mkdir_p liberty_home
          FileUtils.ln_sf(Pathname.new(File.join(root, 'wlp', 'usr')).relative_path_from(Pathname.new(liberty_home)), liberty_home)
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'defaultServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'defaultServer', 'server.xml'), 'w') do |file|
            file.write('your text')
          end
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'defaultServer', 'jvm.options'), 'w') do |file|
            file.write('provided-opt-1')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.jar'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          java_opts: %w(test-opt-2 test-opt-1), # default options, normally set by jre (ibmjdk.rb) before container (liberty.rb) code
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).release

          jvm_options_file = File.join(root, 'wlp', 'usr', 'servers', 'defaultServer', 'jvm.options')
          expect(File.exists?(jvm_options_file)).to be_true
          file_contents = File.read(jvm_options_file)
          expect(file_contents).to match(/provided-opt-1/)
          expect(file_contents).to match(/test-opt-1/)
          expect(file_contents).to match(/test-opt-2/)
          expect(file_contents).to match(DISABLE_2PC_JAVA_OPT_REGEX)
          # default options before user options to allow overriding, each on it's own line.
          # skip options in the regex by allowing multiple or zero collections of : any
          # normal character zero or more times followed by a newline.
          expect(file_contents).to match(/test-opt-1\n(.*\n)*provided-opt-1\n/)
          expect(file_contents).to match(/test-opt-2\n(.*\n)*provided-opt-1\n/)
        end
      end

      it 'should use jvm.options file if one is provided in server directory case.' do
        Dir.mktmpdir do |root|
          Dir.mkdir File.join(root, 'WEB-INF')
          FileUtils.mkdir_p File.join(root, '.liberty', 'usr', 'servers', 'defaultServer')
          File.open(File.join(root, 'server.xml'), 'w') do |file|
            file.write('your text')
          end
          File.open(File.join(root, 'jvm.options'), 'w') do |file|
            file.write('provided-opt-1')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.jar'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          java_opts: %w(test-opt-2 test-opt-1), # default options, normally set by jre (ibmjdk.rb) before container (liberty.rb) code
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).release

          jvm_options_file = File.join(root, 'jvm.options')
          expect(File.exists?(jvm_options_file)).to be_true
          expect(File.read(jvm_options_file)).to match(/provided-opt-1/)
          expect(File.read(jvm_options_file)).to match(/test-opt-1/)

          jvm_options_file = File.join(root, '.liberty', 'usr', 'servers', 'defaultServer', 'jvm.options')
          expect(File.exists?(jvm_options_file)).to be_true
          file_contents = File.read(jvm_options_file)
          expect(file_contents).to match(/provided-opt-1/)
          expect(file_contents).to match(/test-opt-1/)
          expect(file_contents).to match(/test-opt-2/)
          expect(file_contents).to match(DISABLE_2PC_JAVA_OPT_REGEX)
          # default options before user options to allow overriding, each on it's own line.
          # skip options in the regex by allowing multiple or zero collections of : any
          # normal character zero or more times followed by a newline.
          expect(file_contents).to match(/test-opt-1\n(.*\n)*provided-opt-1\n/)
          expect(file_contents).to match(/test-opt-2\n(.*\n)*provided-opt-1\n/)
        end
      end

      it 'should use server jvm.options file instead of the root one if both are provided.' do
        Dir.mktmpdir do |root|
          Dir.mkdir File.join(root, 'WEB-INF')
          liberty_home = File.join(root, '.liberty')
          FileUtils.mkdir_p liberty_home
          FileUtils.ln_sf(Pathname.new(File.join(root, 'wlp', 'usr')).relative_path_from(Pathname.new(liberty_home)), liberty_home)
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'defaultServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'defaultServer', 'server.xml'), 'w') do |file|
            file.write('your text')
          end
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'defaultServer', 'jvm.options'), 'w') do |file|
            file.write('good-opt-1')
          end
          File.open(File.join(root, 'jvm.options'), 'w') do |file|
            file.write('bad-opt-1')
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.jar'))

          library_directory = File.join(root, '.lib')
          FileUtils.mkdir_p(library_directory)
          Liberty.new(
          app_dir: root,
          lib_directory: library_directory,
          configuration: {},
          environment: {},
          java_opts: '',
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).release

          jvm_options_file = File.join(root, 'wlp', 'usr', 'servers', 'defaultServer', 'jvm.options')
          expect(File.exists?(jvm_options_file)).to be_true
          file_contents = File.read(jvm_options_file)
          expect(file_contents).to match(/good-opt-1/)
          expect(file_contents).to match(DISABLE_2PC_JAVA_OPT_REGEX)
          expect(file_contents).not_to match(/bad-opt-1/)
        end
      end

      it 'should return correct execution command for the WEB-INF case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty', root)
          command = Liberty.new(
            app_dir: File.join(root, 'container_liberty'),
            java_home: 'test-java-home',
            java_opts: '',
            configuration: {},
            license_ids: {}
          ).release

          expect(command).to eq(".liberty/create_vars.rb .liberty/usr/servers/defaultServer/runtime-vars.xml && JAVA_HOME=\"$PWD/test-java-home\" .liberty/bin/server run defaultServer")
        end
      end

      it 'should return correct execution command for the META-INF case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_ear', root)
          command = Liberty.new(
            app_dir: File.join(root, 'container_liberty_ear'),
            java_home: 'test-java-home',
            java_opts: '',
            configuration: {},
            license_ids: {}
          ).release

          expect(command).to eq(".liberty/create_vars.rb .liberty/usr/servers/defaultServer/runtime-vars.xml && JAVA_HOME=\"$PWD/test-java-home\" .liberty/bin/server run defaultServer")
        end
      end

      it 'should return correct execution command for the zipped-up server case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_server', root)
          command = Liberty.new(
            app_dir: File.join(root, 'container_liberty_server'),
            java_home: 'test-java-home',
            java_opts: '',
            configuration: {},
            license_ids: {}
          ).release

          expect(command).to eq(".liberty/create_vars.rb .liberty/usr/servers/myServer/runtime-vars.xml && JAVA_HOME=\"$PWD/test-java-home\" .liberty/bin/server run myServer")
        end
      end

      it 'should return correct execution command for single-server case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_single_server', root)
          command = Liberty.new(
            app_dir: File.join(root, 'container_liberty_single_server'),
            java_home: 'test-java-home',
            java_opts: '',
            configuration: {},
            license_ids: {}
          ).release

          expect(command).to eq(".liberty/create_vars.rb .liberty/usr/servers/defaultServer/runtime-vars.xml && JAVA_HOME=\"$PWD/test-java-home\" .liberty/bin/server run defaultServer")
        end
      end

      it 'should throw an error when there are multiple servers to deploy' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write("<httpEndpoint id=\"defaultHttpEndpoint\" host=\"*\" httpPort=\"9080\" httpsPort=\"9443\" />")
          end

          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'otherServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'otherServer', 'server.xml'), 'w') do |file|
            file.write("<httpEndpoint id=\"defaultHttpEndpoint\" host=\"*\" httpPort=\"9080\" httpsPort=\"9443\" />")
          end

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          expect do
            Liberty.new(
            app_dir: root,
            java_home: 'test-java-home',
            java_opts: %w(test-opt-2 test-opt-1),
            configuration: {},
            license_ids: {}
            ).release
          end.to raise_error(/Incorrect\ number\ of\ servers\ to\ deploy/)
        end
      end
    end
  end

  describe 'Liberty finds all applications' do
    before(:each) do
      LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
      .and_return(LIBERTY_VERSION)
    end

    it 'finds a single war' do
      Dir.mktmpdir do |root|
        FileUtils.cp('spec/fixtures/container_liberty_single_server/server.xml', root)
        app_dir = File.join(root, 'apps')
        spring_dir = File.join(app_dir, 'spring.war')
        FileUtils.mkdir_p(spring_dir)
        FileUtils.cp_r('spec/fixtures/framework_auto_reconfiguration_servlet_2', spring_dir)
        liberty_container = Liberty.new(
        app_dir: root,
        configuration: {},
        license_ids: {}
        )

        apps = liberty_container.apps
        expect(apps).to match_array([spring_dir])
        expect(File.directory?(spring_dir)).to be_true
      end
    end

    it 'finds a single ear' do
      Dir.mktmpdir do |root|
        FileUtils.cp('spec/fixtures/container_liberty_single_server/server.xml', root)
        app_dir = File.join(root, 'apps')
        spring_dir = File.join(app_dir, 'spring.ear')
        FileUtils.mkdir_p(spring_dir)
        FileUtils.cp_r('spec/fixtures/framework_auto_reconfiguration_servlet_2', spring_dir)
        liberty_container = Liberty.new(
        app_dir: root,
        configuration: {},
        license_ids: {}
        )

        apps = liberty_container.apps
        expect(apps).to match_array([spring_dir])
        expect(File.directory?(spring_dir)).to be_true
      end
    end

    it 'finds an expanded war' do
      Dir.mktmpdir do |root|
        FileUtils.cp('spec/fixtures/container_liberty_single_server/server.xml', root)
        app_dir = File.join(root, 'apps')
        spring1_war = File.join(app_dir, 'spring.war')
        FileUtils.mkdir_p(app_dir)
        FileUtils.cp('spec/fixtures/stub-spring.war', spring1_war)
        liberty_container = Liberty.new(
        app_dir: root,
        configuration: {},
        license_ids: {}
        )

        apps = liberty_container.apps
        expect(apps).to match_array([spring1_war])
        expect(File.directory?(spring1_war)).to be_true
      end
    end

    it 'finds an expanded ear' do
      Dir.mktmpdir do |root|
        FileUtils.cp('spec/fixtures/container_liberty_single_server/server.xml', root)
        app_dir = File.join(root, 'apps')
        spring1_ear = File.join(app_dir, 'spring.ear')
        FileUtils.mkdir_p(app_dir)
        FileUtils.cp('spec/fixtures/stub-spring.ear', spring1_ear)
        liberty_container = Liberty.new(
        app_dir: root,
        configuration: {},
        license_ids: {}
        )

        apps = liberty_container.apps
        expect(apps).to match_array([spring1_ear])
        expect(File.directory?(spring1_ear)).to be_true
      end
    end

    it 'finds multiple applications' do
      Dir.mktmpdir do |root|
        FileUtils.cp('spec/fixtures/container_liberty_single_server/server.xml', root)
        app_dir = File.join(root, 'apps', 'wars')
        app_dir2 = File.join(root, 'apps', 'ears')
        spring1_war = File.join(app_dir, 'spring1.war')
        spring2_war = File.join(app_dir, 'spring2.war')
        spring1_ear = File.join(app_dir, 'spring1.ear')
        spring2_ear = File.join(app_dir, 'spring2.ear')
        FileUtils.mkdir_p(app_dir)
        FileUtils.mkdir_p(app_dir2)
        FileUtils.cp('spec/fixtures/stub-spring.war', spring1_war)
        FileUtils.cp('spec/fixtures/stub-spring.war', spring2_war)
        FileUtils.cp('spec/fixtures/stub-spring.ear', spring1_ear)
        FileUtils.cp('spec/fixtures/stub-spring.ear', spring2_ear)
        liberty_container = Liberty.new(
        app_dir: root,
        configuration: {},
        license_ids: {}
        )

        apps = liberty_container.apps
        expect(apps).to match_array([spring1_war, spring2_war, spring1_ear, spring2_ear])
        expect(File.directory?(spring1_war)).to be_true
        expect(File.directory?(spring2_war)).to be_true
        expect(File.directory?(spring1_ear)).to be_true
        expect(File.directory?(spring2_ear)).to be_true
      end
    end
  end

end

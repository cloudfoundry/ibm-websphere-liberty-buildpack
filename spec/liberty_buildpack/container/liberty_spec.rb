# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013-2014 the original author or authors.
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
require 'logging_helper'
require 'liberty_buildpack/container/liberty'
require 'liberty_buildpack/container/container_utils'

module LibertyBuildpack::Container

  describe Liberty do
    include_context 'logging_helper'    # logging_helper only for now

    LIBERTY_VERSION = LibertyBuildpack::Util::TokenizedVersion.new('8.5.5')
    LIBERTY_SINGLE_DOWNLOAD_URI = 'test-liberty-uri.tar.gz'.freeze # end of URI (here ".tar.gz") is significant in liberty container code
    LIBERTY_DETAILS = [LIBERTY_VERSION, LIBERTY_SINGLE_DOWNLOAD_URI, 'spec/fixtures/license.html']
    DISABLE_2PC_JAVA_OPT_REGEX = '-Dcom.ibm.tx.jta.disable2PC=true'.freeze

    let(:application_cache) { double('ApplicationCache') }
    let(:component_index) { double('ComponentIndex') }

    before do
      # return license file by default
      application_cache.stub(:get).and_yield(File.open('spec/fixtures/license.html'))
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
          apps.each { |file| expect(File.directory? file).to eq(true) }
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

        expect(detected).to eq(%w(WAR liberty-8.5.5))
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

        expect(detected).to eq(%w(EAR liberty-8.5.5))
      end

      it 'should not detect when WEB-INF is present in a Java main application' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)
        detected = Liberty.new(
        app_dir: 'spec/fixtures/container_main_with_web_inf',
        configuration: {},
        java_home: '',
        java_opts: [],
        license_ids: {}
        ).detect

        expect(detected).to be_nil
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

        expect(detected).to eq(%w(SVR-PKG liberty-8.5.5))
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

        expect(detected).to eq(%w(SVR-DIR liberty-8.5.5))
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
        end.to raise_error(/The\ pushed\ server\ is\ incorrectly\ packaged.\ Use\ the\ command\ 'server\ package\ --include=usr'\ to\ package\ a\ server/)
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

      it 'should update the common_paths for Heroku provided by the buildpack to include the Liberty container' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)

        liberty = Liberty.new(
        app_dir: 'spec/fixtures/container_liberty',
        configuration: {},
        common_paths: CommonPaths.new('.'),
        java_home: '',
        java_opts: [],
        license_ids: {}
        )
        liberty.detect

        actual_common_paths = liberty.instance_variable_get(:@common_paths)
        expect(actual_common_paths.instance_variable_get(:@relative_location)).to eq('../../../..')
        expect(actual_common_paths.instance_variable_get(:@relative_to_base)).to eq('../../../..')
      end

      it 'should update the common_paths for CF default to Liberty path when common_paths is not provided in the context' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)

        liberty = Liberty.new(
        app_dir: 'spec/fixtures/container_liberty',
        configuration: {},
        java_home: '',
        java_opts: [],
        license_ids: {}
        )
        liberty.detect

        actual_common_paths = liberty.instance_variable_get(:@common_paths)
        expect(actual_common_paths.instance_variable_get(:@relative_location)).to eq('../../../..')
        expect(actual_common_paths.instance_variable_get(:@relative_to_base)).to eq('../../../../..')
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

      it 'should not write VCAP_SERVICES credentials as debug info' do
        old_level = ENV['JBP_LOG_LEVEL']
        begin
          Dir.mktmpdir do |root|
            Dir.mkdir File.join(root, 'WEB-INF')

            LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
            .and_return(LIBERTY_DETAILS)
            LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
            component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

            LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
            application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

            secret = 'VERY SECRET PHRASE'
            plaindata = 'PLAIN DATA'
            ENV['JBP_LOG_LEVEL'] = 'debug'

            LibertyBuildpack::Diagnostics::LoggerFactory.send :close # suppress warnings
            LibertyBuildpack::Diagnostics::LoggerFactory.create_logger root

            library_directory = File.join(root, '.lib')
            FileUtils.mkdir_p(library_directory)
            Liberty.new(
            app_dir: root,
            lib_directory: library_directory,
            configuration: {},
            environment: {},
            vcap_services: { 'data' => [{ 'credentials' => { 'identity' => secret }, 'data' => plaindata }] },
            license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
            ).compile

            log_content = File.read LibertyBuildpack::Diagnostics.get_buildpack_log root

            expect(log_content).not_to match(secret)
            expect(log_content).to match(/PRIVATE DATA HIDDEN/)
            expect(log_content).to match(plaindata)
          end
        ensure
          ENV['JBP_LOG_LEVEL'] = old_level
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

          expect(File.exists?(File.join bin_dir, 'server')).to eq(true)
          expect(File.exists?(File.join bin_dir, 'featureManager')).to eq(true)
          expect(File.exists?(File.join bin_dir, 'securityUtility')).to eq(true)
          expect(File.exists?(File.join bin_dir, 'productInfo')).to eq(true)
          expect(File.exists?(default_server_xml)).to eq(true)
          expect(File.exists?(rest_connector)).to eq(true)

          icap_properties = File.join liberty_dir, 'etc', 'extensions', 'icap.properties'
          expect(File.exists?(icap_properties)).to eq(true)
          icap_properties_content = File.read icap_properties
          expect(icap_properties_content.include? 'productInstall=.liberty/icap').to eq(true)
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

          expect(File.exists?(File.join bin_dir, 'server')).to eq(true)
          expect(File.exists?(File.join bin_dir, 'featureManager')).to eq(true)
          expect(File.exists?(File.join bin_dir, 'securityUtility')).to eq(true)
          expect(File.exists?(File.join bin_dir, 'productInfo')).to eq(true)
          expect(File.exists?(default_server_xml)).to eq(true)
          expect(File.exists?(rest_connector)).to eq(true)
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

          expect(File.exists?(File.join bin_dir, 'server')).to eq(true)
          expect(File.exists?(File.join bin_dir, 'featureManager')).to eq(true)
          expect(File.exists?(File.join bin_dir, 'securityUtility')).to eq(true)
          expect(File.exists?(File.join bin_dir, 'productInfo')).to eq(true)
          expect(File.exists?(default_server_xml)).to eq(true)
          expect(File.exists?(rest_connector)).to eq(true)
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

          expect(File.exists?(File.join root, '.java', 'overlay.txt')).to eq(true)
          expect(File.exists?(File.join root, '.java', 'test.txt')).to eq(true)
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

          expect(File.exists?(File.join root, '.java', 'overlay.txt')).to eq(true)
          expect(File.exists?(File.join root, '.java', 'test.txt')).to eq(true)
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
          expect(File.exists?(server_script)).to eq(true)
          expect(File.executable?(server_script)).to eq(true)
          expect(File.directory? war_file).to eq(true)
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
          expect(File.executable?(server_script)).to eq(true)
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
          expect(File.executable?(server_script)).to eq(true)
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
          expect(File.exists?(server_xml_file)).to eq(true)

          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents.include? '<featureManager>').to eq(true)
          expect(server_xml_contents.include? '<application name="myapp" context-root="/" location="myapp.war"').to eq(true)
          expect(server_xml_contents.include? 'type="war"').to eq(true)
          expect(server_xml_contents.include? 'httpPort="${port}"').to eq(true)
          expect(server_xml_contents.include? '<httpDispatcher enableWelcomePage="false"/>').to eq(true)
          expect(server_xml_contents.include? '<config updateTrigger="mbean"/>').to eq(true)
          expect(server_xml_contents.include? '<applicationMonitor dropinsEnabled="false" updateTrigger="mbean"/>').to eq(true)
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

          expect(File.exists?(droplet_yaml_file)).to eq(true)

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

          expect(File.exists?(droplet_yaml_file)).to eq(false)
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
          expect(File.exists?(server_xml_file)).to eq(true)

          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents.include? '<featureManager>').to eq(true)
          expect(server_xml_contents.include? '<application name="myapp" context-root="/" location="myapp.ear"').to eq(true)
          expect(server_xml_contents.include? 'type="ear"').to eq(true)
          expect(server_xml_contents.include? 'httpPort="${port}"').to eq(true)
          expect(server_xml_contents.include? '<config updateTrigger="mbean"/>').to eq(true)
          expect(server_xml_contents.include? '<applicationMonitor dropinsEnabled="false" updateTrigger="mbean"/>').to eq(true)
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
          expect(Dir.exists?(liberty_directory)).to eq(true)

          server_command = File.join(root, '.liberty', 'bin', 'server')
          expect(File.exists?(server_command)).to eq(true)

          license_files = File.join(root, '.liberty', 'lafiles')
          expect(Dir.exists?(license_files)).to eq(true)

          usr_directory = File.join(root, '.liberty', 'usr')
          expect(File.symlink?(usr_directory)).to eq(true)
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
          expect(Dir.exists?(feature_lib_dir)).to eq(true)
          jar_file = File.join(feature_lib_dir, 'dummy_feature.jar')
          expect(File.exists?(jar_file)).to eq(true)
          mf_dir = File.join(feature_lib_dir, 'features')
          expect(Dir.exists?(mf_dir)).to eq(true)
          mf_file = File.join(mf_dir, 'dummy_feature.mf')
          expect(File.exists?(mf_file)).to eq(true)
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
          expect(Dir.exists?(feature_lib_dir)).to eq(true)
          jar_file = File.join(feature_lib_dir, 'dummy_feature.jar')
          expect(File.exists?(jar_file)).to eq(true)
          jar_file = File.join(feature_lib_dir, 'existing.jar')
          expect(File.exists?(jar_file)).to eq(true)
          mf_dir = File.join(feature_lib_dir, 'features')
          expect(Dir.exists?(mf_dir)).to eq(true)
          mf_file = File.join(mf_dir, 'dummy_feature.mf')
          expect(File.exists?(mf_file)).to eq(true)
          mf_file = File.join(mf_dir, 'existing.mf')
          expect(File.exists?(mf_file)).to eq(true)
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
          expect(Dir.exists?(liberty_directory)).to eq(true)

          server_command = File.join(root, '.liberty', 'bin', 'server')
          expect(File.exists?(server_command)).to eq(true)

          license_files = File.join(root, '.liberty', 'lafiles')
          expect(Dir.exists?(license_files)).to eq(true)

          default_server_directory = File.join(root, '.liberty', 'usr', 'servers', 'defaultServers')
          expect(Dir.exists?(default_server_directory))

          usr_symlink = File.join(root, '.liberty', 'usr', 'servers', 'defaultServer', 'server.xml')
          expect(File.symlink?(usr_symlink)).to eq(true)
          expect(File.readlink(usr_symlink)).to eq(Pathname.new(File.join(root, 'server.xml')).relative_path_from(Pathname.new(default_server_directory)).to_s)

          server_xml_file = File.join root, '.liberty', 'usr', 'servers', 'defaultServer', 'server.xml'
          expect(File.exists?(server_xml_file)).to eq(true)

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
          expect(Dir.exists?(liberty_directory)).to eq(true)

          server_xml_file = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read server_xml_file
          expect(server_xml_contents.include? 'host="*"').to eq(true)
          expect(server_xml_contents.include? 'httpPort="${port}"').to eq(true)
          expect(server_xml_contents.include? 'httpsPort=').to eq(false)
          expect(server_xml_contents).to match(/<webContainer trustHostHeaderPort='true' extractHostHeaderPort='true'\/>/)
          expect(File.exists?(droplet_yaml_file)).to eq(false)
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
          expect(Dir.exists?(liberty_directory)).to eq(true)

          server_xml_file = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read server_xml_file
          expect(server_xml_contents).to match(/<webContainer extractHostHeaderPort="true" trusted="false" trustHostHeaderPort="true"\/>/)
        end
      end

      it 'should not update config or applcationMonitor element if server.xml already contains them' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write("<server><config onError='WARN'/><applicationMonitor pollingRate='600ms'/></server>")
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
          expect(Dir.exists?(liberty_directory)).to eq(true)

          server_xml_file = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read server_xml_file
          expect(server_xml_contents).to match(/<config onError="WARN"\/>/)
          expect(server_xml_contents).to match(/<applicationMonitor pollingRate="600ms"\/>/)
        end
      end

      it 'should not disable dropins if dropins directory contains files' do
        Dir.mktmpdir do |root|
          root = File.join(root, 'app')
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write('<server></server>')
          end
          dropins = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'dropins')
          FileUtils.mkdir_p dropins
          File.open(File.join(dropins, 'foo.jar'), 'w') do |file|
            file.write("i'm a jar")
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
          expect(Dir.exists?(liberty_directory)).to eq(true)

          server_xml_file = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read server_xml_file
          expect(server_xml_contents).to match(/<config updateTrigger='mbean'\/>/)
          expect(server_xml_contents).to match(/<applicationMonitor dropinsEnabled='true' updateTrigger='mbean'\/>/)
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

      it 'should inline the contents of the included files' do
        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_server_with_includes', root)

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
            app_dir: File.join(root, 'container_liberty_server_with_includes'),
            configuration: {},
            environment: {},
            license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          original_xml_file = File.join(root, 'container_liberty_server_with_includes', 'wlp', 'usr', 'servers', 'myServer', 'server.xml.org')
          expect(File.file?(original_xml_file)).to eq(true)

          server_xml_file = File.join(root, 'container_liberty_server_with_includes', 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents).to match(/<featureManager>/)
          expect(server_xml_contents).to match(/<application id="blog" location="blog.war" name="blog" type="war"\/>/)
          expect(server_xml_contents).not_to match(/<include location="variables.xml"\/>/)
          expect(server_xml_contents).to match(/<variable name="port" value="62147"\/>/)
          expect(server_xml_contents).not_to match(/<include location="moreVariables.xml"\/>/)
          expect(server_xml_contents).to match(%r{<variable name="home" value="\/home\/vcap\/app"\/>})
          expect(server_xml_contents).not_to match(/<include location="blogDS.xml"\/>/)
          expect(server_xml_contents).to match(/<jdbcDriver id="derbyEmbedded">/)
          expect(server_xml_contents).to match(/<dataSource id="blogDS" jndiName="jdbc\/blogDS" jdbcDriverRef="derbyEmbedded">/)
        end
      end

      it 'should inline the contents of the included file located via property' do
        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_server_with_includes_property', root)

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
            app_dir: File.join(root, 'container_liberty_server_with_includes_property'),
            configuration: {},
            environment: {},
            license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          original_xml_file = File.join(root, 'container_liberty_server_with_includes_property', 'wlp', 'usr', 'servers', 'myServer', 'server.xml.org')
          expect(File.file?(original_xml_file)).to eq(true)

          server_xml_file = File.join(root, 'container_liberty_server_with_includes_property', 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents).to match(/<featureManager>/)
          expect(server_xml_contents).to match(/<application id="blog" location="blog.war" name="blog" type="war"\/>/)
          expect(server_xml_contents).not_to match(/<include location="blogDS.xml" optional="true"\/>/)
          expect(server_xml_contents).to match(/<jdbcDriver id="derbyEmbedded">/)
          expect(server_xml_contents).to match(/<dataSource id="blogDS" jndiName="jdbc\/blogDS" jdbcDriverRef="derbyEmbedded">/)
        end
      end

      it 'should ignore the include element if the optional attribute is true and the included file is not found' do
        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_server_with_includes_ignored', root)

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          Liberty.new(
            app_dir: File.join(root, 'container_liberty_server_with_includes_ignored'),
            configuration: {},
            environment: {},
            license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
          ).compile

          original_xml_file = File.join(root, 'container_liberty_server_with_includes_ignored', 'wlp', 'usr', 'servers', 'myServer', 'server.xml.org')
          expect(File.file?(original_xml_file)).to eq(true)

          server_xml_file = File.join(root, 'container_liberty_server_with_includes_ignored', 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents).to match(/<featureManager>/)
          expect(server_xml_contents).to match(/<application id="blog" location="blog.war" name="blog" type="war"\/>/)
          expect(server_xml_contents).to match(/<include location="blogDS.xml" optional="true"\/>/)
        end
      end

      it 'should fail if the optional attribute is false and the included file is not found' do
        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_server_with_includes_not_found', root)

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          expect do
            Liberty.new(
              app_dir: File.join(root, 'container_liberty_server_with_includes_not_found'),
              configuration: {},
              environment: {},
              license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
            ).compile
          end.to raise_error
        end
      end

      it 'should fail if the included file location uses http' do
        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_server_with_includes_http', root)

          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
          .and_return(LIBERTY_DETAILS)

          LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
          component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

          expect do
            Liberty.new(
              app_dir: File.join(root, 'container_liberty_server_with_includes_http'),
              configuration: {},
              environment: {},
              license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
            ).compile
          end.to raise_error
        end
      end
    end

    it 'should work with a server.xml file that contains non-ASCII characters' do
      Dir.mktmpdir do |root|
        FileUtils.cp_r('spec/fixtures/container_liberty_server_non_ascii_chars', root)

        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_DETAILS)

        LibertyBuildpack::Repository::ComponentIndex.stub(:new).and_return(component_index)
        component_index.stub(:components).and_return({ 'liberty_core' => LIBERTY_SINGLE_DOWNLOAD_URI })

        LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.tar.gz'))

        Liberty.new(
          app_dir: File.join(root, 'container_liberty_server_non_ascii_chars'),
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
        ).compile
      end
    end

    context 'droplet.yaml' do

      def generate(root, xml)
          FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
          File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
            file.write("<server><httpEndpoint id=\"defaultHttpEndpoint\" host=\"localhost\" httpPort=\"9080\" httpsPort=\"9443\" />#{xml}</server>")
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
      end

      def check_appstate(app_xml, app_name)
        Dir.mktmpdir do |root|
          droplet_yaml_file = File.join root, 'droplet.yaml'
          root = File.join(root, 'app')

          generate(root, app_xml)

          liberty_directory = File.join root, '.liberty'
          expect(Dir.exists?(liberty_directory)).to eq(true)

          server_xml_file = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents).to include("<httpDispatcher enableWelcomePage='false'/>")
          expect(server_xml_contents).to include("<config updateTrigger='mbean'/>")
          expect(server_xml_contents).to include("<applicationMonitor dropinsEnabled='false' updateTrigger='mbean'/>")
          expect(server_xml_contents).to include("<appstate appName='#{app_name}' markerPath='${home}/.liberty.state'/>")

          expect(File.exists?(droplet_yaml_file)).to eq(true)
        end
      end

      def check_no_appstate(app_xml)
        Dir.mktmpdir do |root|
          droplet_yaml_file = File.join root, 'droplet.yaml'
          root = File.join(root, 'app')

          generate(root, app_xml)

          liberty_directory = File.join root, '.liberty'
          expect(Dir.exists?(liberty_directory)).to eq(true)

          server_xml_file = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml')
          server_xml_contents = File.read(server_xml_file)
          expect(server_xml_contents).to include("<httpDispatcher enableWelcomePage='false'/>")
          expect(server_xml_contents).to include("<config updateTrigger='mbean'/>")
          expect(server_xml_contents).to include("<applicationMonitor dropinsEnabled='false' updateTrigger='mbean'/>")
          expect(server_xml_contents).not_to match(/<appstate.*\/>/)

          expect(File.exists?(droplet_yaml_file)).to eq(false)
        end
      end

      it 'should add droplet.yaml when server xml contains myapp application' do
        check_appstate("<application name=\"myapp\" />", 'myapp')
      end

      it 'should add droplet.yaml when server xml contains foo application' do
        check_appstate("<application name=\"foo\" />", 'foo')
      end

      it 'should add droplet.yaml when server xml contains foo webApplication' do
        check_appstate("<webApplication name=\"fooWar\" />", 'fooWar')
      end

      it 'should add droplet.yaml when server xml contains foo enterpriseApplication' do
        check_appstate("<enterpriseApplication name=\"fooEar\" />", 'fooEar')
      end

      it 'should NOT add droplet.yaml when server xml contains two applications' do
        check_no_appstate("<application name=\"foo\" /><application name=\"foo2\" />")
      end

      it 'should NOT add droplet.yaml when server xml contains two webApplications' do
        check_no_appstate("<webApplication name=\"fooWar\" /><webApplication name=\"fooWar2\" />")
      end

      it 'should NOT add droplet.yaml when server xml contains two enterpriseApplications' do
        check_no_appstate("<enterpriseApplication name=\"fooEar\" /><enterpriseApplication name=\"fooEar2\" />")
      end

      it 'should NOT add droplet.yaml when server xml contains two different application types' do
        check_no_appstate("<application name=\"foo\" /><webApplication name=\"fooWar\" />")
      end

    end

    describe 'release' do
      let(:test_java_home) { 'test-java-home' }

      context 'JVM Options' do
        def create_server_xml(path, text = 'your text')
          FileUtils.mkdir_p(path)
          File.open(File.join(path, 'server.xml'), 'w') do |file|
            file.write(text)
          end
        end

        def create_jvm_options(path, text)
          File.open(File.join(path, 'jvm.options'), 'w') do |file|
            file.write(text)
          end
        end

        def jvm_opts(jvm_options_file)
          expect(File.exists?(jvm_options_file)).to eq(true)
          File.read(jvm_options_file)
        end

        # Helper method for setting up the tests that check for the jvm options file contents during the release
        # stage. It will return the contents of the expected jvm options file as specified in the parameters,
        # relative to the root of the application directory, after the release stage has executed.
        #
        # @param [String]   name and path of the jvm options file relative to the application directory to be tested
        # @param [String]   name and path of an optional jvm options file relative to the application directory to be tested
        def jvm_opt_test(jvmfile1, jvmfile2 = nil)
          # basic context that test cases can customize
          context = { configuration: {}, environment: {} }

          Dir.mktmpdir do |root|
            # each app directory requires a .liberty
            liberty_home = File.join(root, '.liberty')
            FileUtils.mkdir_p liberty_home

            # create the common context keys that each test can use
            context[:app_dir] = root
            library_directory = File.join(root, '.lib')
            FileUtils.mkdir_p(library_directory)
            context[:lib_directory] = library_directory
            context[:license_ids] = { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }

            # create repository stubs
            LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
            .and_return(LIBERTY_DETAILS)

            LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
            application_cache.stub(:get).with(LIBERTY_SINGLE_DOWNLOAD_URI).and_yield(File.open('spec/fixtures/wlp-stub.jar'))

            # provide the unit tests with the application root directory and basic context to customize
            yield root, context, liberty_home

            # Invoke the Liberty release stage
            Liberty.new(context).release

            # read the resulting jvm.options file(s) and return its contents for test validation
            file_contents1 = jvm_opts(File.join(root, jvmfile1)) if jvmfile1
            file_contents2 = jvm_opts(File.join(root, jvmfile2)) if jvmfile2

            jvmfile2.nil? ? file_contents1 : [file_contents1, file_contents2]
          end
        end

        it 'should generate a jvm.options file if one is not provided in server package case' do
          jvm_opts = jvm_opt_test(File.join('wlp', 'usr', 'servers', 'anyServer', 'jvm.options')) do |root, context, liberty_home|

            FileUtils.ln_sf(Pathname.new(File.join(root, 'wlp', 'usr')).relative_path_from(Pathname.new(liberty_home)), liberty_home)
            create_server_xml(File.join(root, 'wlp', 'usr', 'servers', 'anyServer'))

            context[:java_opts] = %w(test-opt-2 test-opt-1)
          end

          expect(jvm_opts).to match(/test-opt-1/)
          expect(jvm_opts).to match(/test-opt-2/)
          expect(jvm_opts).to match(DISABLE_2PC_JAVA_OPT_REGEX)
        end

        it 'should generate a jvm.options file if one is not provided in server directory case' do
          root_jvm_opts, server_jvm_opts = jvm_opt_test('jvm.options', File.join('.liberty', 'usr', 'servers', 'defaultServer', 'jvm.options')) do |root, context|
            FileUtils.mkdir_p File.join(root, '.liberty', 'usr', 'servers', 'defaultServer')
            create_server_xml(root)
            context[:java_opts] = %w(test-opt-2 test-opt-1)
          end

          expect(root_jvm_opts).to match(/test-opt-1/)

          expect(server_jvm_opts).to match(/test-opt-1/)
          expect(server_jvm_opts).to match(/test-opt-2/)
          expect(server_jvm_opts).to match(DISABLE_2PC_JAVA_OPT_REGEX)
        end

        it 'should use jvm.options file if one is provided in server package case.' do
          jvm_opts = jvm_opt_test(File.join('wlp', 'usr', 'servers', 'defaultServer', 'jvm.options')) do |root, context, liberty_home|
            Dir.mkdir File.join(root, 'WEB-INF')

            FileUtils.ln_sf(Pathname.new(File.join(root, 'wlp', 'usr')).relative_path_from(Pathname.new(liberty_home)), liberty_home)
            FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'defaultServer')

            create_server_xml(File.join(root, 'wlp', 'usr', 'servers', 'defaultServer'))
            create_jvm_options(File.join(root, 'wlp', 'usr', 'servers', 'defaultServer'), 'provided-opt-1')

            context[:java_opts] = %w(test-opt-2 test-opt-1) # default options, normally set by jre (ibmjdk.rb) before container (liberty.rb) code
          end

          expect(jvm_opts).to match(/provided-opt-1/)
          expect(jvm_opts).to match(/test-opt-1/)
          expect(jvm_opts).to match(/test-opt-2/)
          expect(jvm_opts).to match(DISABLE_2PC_JAVA_OPT_REGEX)
          # default options before user options to allow overriding, each on it's own line.
          # skip options in the regex by allowing multiple or zero collections of : any
          # normal character zero or more times followed by a newline.
          expect(jvm_opts).to match(/test-opt-1\n(.*\n)*provided-opt-1\n/)
          expect(jvm_opts).to match(/test-opt-2\n(.*\n)*provided-opt-1\n/)
        end

        it 'should use jvm.options file if one is provided in server directory case.' do
          root_jvm_opts, server_jvm_opts = jvm_opt_test('jvm.options', File.join('.liberty', 'usr', 'servers', 'defaultServer', 'jvm.options')) do |root, context, liberty_home|
            Dir.mkdir File.join(root, 'WEB-INF')
            FileUtils.mkdir_p File.join(liberty_home, 'usr', 'servers', 'defaultServer')
            create_server_xml(root)
            create_jvm_options(root, 'provided-opt-1')

            context[:java_opts] = %w(test-opt-2 test-opt-1) # default options, normally set by jre (ibmjdk.rb) before container (liberty.rb) code
          end

          expect(root_jvm_opts).to match(/provided-opt-1/)
          expect(root_jvm_opts).to match(/test-opt-1/)

          expect(server_jvm_opts).to match(/provided-opt-1/)
          expect(server_jvm_opts).to match(/test-opt-1/)
          expect(server_jvm_opts).to match(/test-opt-2/)
          expect(server_jvm_opts).to match(DISABLE_2PC_JAVA_OPT_REGEX)
          # default options before user options to allow overriding, each on it's own line.
          # skip options in the regex by allowing multiple or zero collections of : any
          # normal character zero or more times followed by a newline.
          expect(server_jvm_opts).to match(/test-opt-1\n(.*\n)*provided-opt-1\n/)
          expect(server_jvm_opts).to match(/test-opt-2\n(.*\n)*provided-opt-1\n/)
        end

        it 'should use server jvm.options file instead of the root one if both are provided.' do
          jvm_opts = jvm_opt_test(File.join('wlp', 'usr', 'servers', 'defaultServer', 'jvm.options')) do |root, context, liberty_home|
            Dir.mkdir File.join(root, 'WEB-INF')
            FileUtils.ln_sf(Pathname.new(File.join(root, 'wlp', 'usr')).relative_path_from(Pathname.new(liberty_home)), liberty_home)
            create_server_xml(File.join(root, 'wlp', 'usr', 'servers', 'defaultServer'))
            create_jvm_options(File.join(root, 'wlp', 'usr', 'servers', 'defaultServer'), 'good-opt-1')
            create_jvm_options(File.join(root), 'bad-opt-1')

            context[:java_opts] = ''
          end

          expect(jvm_opts).to match(/good-opt-1/)
          expect(jvm_opts).to match(DISABLE_2PC_JAVA_OPT_REGEX)
          expect(jvm_opts).not_to match(/bad-opt-1/)
        end

      end # end of JVM Options Context

      it 'should return correct execution command for the WEB-INF case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty', root)
          command = Liberty.new(
            app_dir: File.join(root, 'container_liberty'),
            java_home: test_java_home,
            java_opts: '',
            configuration: {},
            license_ids: {}
          ).release

          expect(command).to eq(".liberty/create_vars.rb .liberty/usr/servers/defaultServer/runtime-vars.xml && JAVA_HOME=\"$PWD/#{test_java_home}\" .liberty/bin/server run defaultServer")
        end
      end

      it 'should return correct execution command for the META-INF case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_ear', root)
          command = Liberty.new(
            app_dir: File.join(root, 'container_liberty_ear'),
            java_home: test_java_home,
            java_opts: '',
            configuration: {},
            license_ids: {}
          ).release

          expect(command).to eq(".liberty/create_vars.rb .liberty/usr/servers/defaultServer/runtime-vars.xml && JAVA_HOME=\"$PWD/#{test_java_home}\" .liberty/bin/server run defaultServer")
        end
      end

      it 'should return correct execution command for the zipped-up server case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_server', root)
          command = Liberty.new(
            app_dir: File.join(root, 'container_liberty_server'),
            java_home: test_java_home,
            java_opts: '',
            configuration: {},
            license_ids: {}
          ).release

          expect(command).to eq(".liberty/create_vars.rb .liberty/usr/servers/myServer/runtime-vars.xml && JAVA_HOME=\"$PWD/#{test_java_home}\" .liberty/bin/server run myServer")
        end
      end

      it 'should return correct execution command for single-server case' do
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(LIBERTY_VERSION) if block }
        .and_return(LIBERTY_VERSION)

        Dir.mktmpdir do |root|
          FileUtils.cp_r('spec/fixtures/container_liberty_single_server', root)
          command = Liberty.new(
            app_dir: File.join(root, 'container_liberty_single_server'),
            java_home: test_java_home,
            java_opts: '',
            configuration: {},
            license_ids: {}
          ).release

          expect(command).to eq(".liberty/create_vars.rb .liberty/usr/servers/defaultServer/runtime-vars.xml && JAVA_HOME=\"$PWD/#{test_java_home}\" .liberty/bin/server run defaultServer")
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
            java_home: test_java_home,
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
        expect(File.directory?(spring_dir)).to eq(true)
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
        expect(File.directory?(spring_dir)).to eq(true)
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
        expect(File.directory?(spring1_war)).to eq(true)
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
        expect(File.directory?(spring1_ear)).to eq(true)
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
        expect(File.directory?(spring1_war)).to eq(true)
        expect(File.directory?(spring2_war)).to eq(true)
        expect(File.directory?(spring1_ear)).to eq(true)
        expect(File.directory?(spring2_ear)).to eq(true)
      end
    end
  end

end

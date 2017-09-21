# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2017 the original author or authors.
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
require 'component_helper'
require 'liberty_buildpack/framework/contrast_security_agent'
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Framework

  describe 'ContrastSecurityAgent' do
    include_context 'component_helper' # component context

    # test data
    let(:contrast_security_home) { '.contrast' } # the expected staged contrast security agent directory
    let(:application_cache) { double('ApplicationCache') }
    let(:version) { '3.4.1' }
    let(:versionid) { "contrast-engine-#{version}" }
    let(:jar_name) { "contrast-engine-#{version}.jar" }
    let(:config_name) { 'contrast.config' }

    before do |example|
      # an index.yml entry returned from the index.yml of the contrast security repository
      if example.metadata[:index_version]
        # contrast security index.yml info provided by tests
        index_version = example.metadata[:index_version]
        index_uri = example.metadata[:index_uri]
        index_license = example.metadata[:index_license]
      else
        # default values for the contrast security index.yml info for tests
        index_version = version
        index_uri = "https://downloadsite/contrast-security/#{versionid}.jar"
      end

      # By default, always stub the return of a valid index.yml entry
      find_item = example.metadata[:return_find_item].nil? ? true : example.metadata[:return_find_item]
      if find_item
        index_yml_entry = [LibertyBuildpack::Util::TokenizedVersion.new(index_version), index_uri, index_license]
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(index_yml_entry)
      else
        # tests can set find_item=false and a raise_error_message to mock a failed return of processing the index.yml
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_raise(example.metadata[:raise_error_message])
      end

      # For a download request of a contrast security agent jar, return the fixture jar
      LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with(index_uri).and_yield(File.open('spec/fixtures/stub-contrast-security-agent.jar'))
    end

    describe 'configuration' do
      it 'must have v3.+ as the configured version' do
        configuration = YAML.load_file(File.expand_path('../../../config/contrastsecurityagent.yml', File.dirname(__FILE__)))

        expected_version = LibertyBuildpack::Util::TokenizedVersion.new('3.4.1')
        actual_version = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration)[0]

        expect(actual_version).to eq(expected_version)
      end
    end

    describe 'detect',
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] } do

      subject(:detected) do
        ContrastSecurityAgent.new(context).detect
      end

      context 'user provided service' do
        def_type = 'servicetype'
        def_name = 'servicename'
        def_label = 'user-provided'
        def_tags = ['atag']
        def_credentials = { 'teamserver_url' => 'https://example.com', 'api_key' => 'test', 'service_key' => 'test', 'username' => 'test_user' }

        it 'should be detected when the service name includes contrast-security substring',
           vcap_services_context: { def_type => [{ 'name' => 'contrast-security', 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }] } do
          expect(detected).to eq(versionid)
        end

        it 'should raise a runtime error for multiple valid contrast security user services',
           vcap_services_context: { def_type => [{ 'name' => 'contrast-security', 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }],
                                    'servicetype2' => [{ 'name' => 'contrast-security', 'label' => def_label, 'tags' => def_tags,
                                                         'credentials' => def_credentials }] } do

          expect { detected }.to raise_error(RuntimeError)
        end

        it 'should be detected when the tag includes contrast-security substring',
           vcap_services_context: { def_type => [{ 'name' => def_name, 'label' => def_label, 'tags' => ['contrast-security'],
                                                   'credentials' => def_credentials }] } do
          expect(detected).to eq(versionid)
        end

        it 'should not be detected unless the name or tag includes contrast security substring',
           vcap_services_context: { def_type => [{ 'name' => def_name, 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }] } do
          expect(detected).to eq(nil)
        end

        it 'should detect a referral tile created user provided service',
           vcap_services_context: { def_type => [{ 'name' => def_name, 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => { 'contrast_referral_tile' => 'true' } }] } do

          expect(detected).to eq(versionid)
        end
      end

      context 'application with no services' do
        it 'should not detect the contrast security service',
           vcap_services_context: {} do
          expect(detected).to eq(nil)
        end
      end

      context 'application with one service' do
        def_credentials = { 'teamserver_url' => 'https://example.com', 'api_key' => 'test', 'service_key' => 'test', 'username' => 'test_user' }
        it 'should be detected when an application has a valid service attribute that includes contrast-security',
           vcap_services_context: { 'contrast-security' => [{ 'name' => 'test-contrast-security', 'label' => 'contrast-security',
                                                              'credentials' => def_credentials }] } do

          expect(detected).to eq(versionid)
        end

        it 'should not be detected if contrast security service does not exist',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-mysql', 'label' => 'mysql',
                                                  'credentials' => { 'licenseKey' => '9876543210fedcba' } }] } do

          expect(detected).to eq(nil)
        end

        it 'should not be detected since name is not used as a match check unless it is a user service',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-contrast security', 'label' => 'mysql',
                                                  'credentials' => def_credentials }] } do

          expect(detected).to eq(nil)
        end
      end

      context 'application with multiple services' do
        def_credentials = { 'teamserver_url' => 'https://example.com', 'api_key' => 'test', 'service_key' => 'test', 'username' => 'test_user' }
        it 'should be detected if one of the services is contrast security',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-mysql', 'label' => 'mysql',
                                                  'credentials' => { 'licenseKey' => '9876543210fedcba' } }],
                                    'contrast-security' => [{ 'name' => 'contrast-security', 'label' => 'contrast-security',
                                                              'credentials' => def_credentials }] } do
          expect(detected).to eq(versionid)
        end

        it 'should raise a runtime error if multiple contrast security services exist',
           vcap_services_context: { 'contrast-security-key1' => [{ 'name' => 'test-name', 'label' => 'contrast-security',
                                                                   'credentials' => { 'licenseKey' => 'abcdef0123456789' } }],
                                    'contrast-security-key2' => [{ 'name' => 'test-name', 'label' => 'contrast-security',
                                                                   'credentials' => def_credentials }] } do

          expect { detected }.to raise_error(RuntimeError)
        end

        it 'should not be detected if none of the services is contrast security',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-mysql', 'label' => 'mysql',
                                                  'credentials' => { 'licenseKey' => '9876543210fedcba' } }],
                                    'sqldb' => [{ 'name' => 'test-sqldb', 'label' => 'sqldb',
                                                  'credentials' => {} }],
                                    'APIConnect' => [{ 'name' => 'API Connect-1', 'label' => 'APIConnect', 'plan' => 'Lite' }] } do
          expect(detected).to eq(nil)
        end
      end

      context 'invalid index.yml entry with a valid contrast security service',
              vcap_services_context: { 'contrast security' => [{ 'name' => 'test-contrast-security', 'label' => 'contrast-security',
                                                                 'credentials' => { 'licenseKey' => 'abcdef0123456789' } }] } do

        it 'should raise an error including the underlying failure if the index.yml could not be processed',
           return_find_item: false, raise_error_message: 'underlying index.yml error' do
          expect(detected).to eq(nil)
        end

      end

    end # end of detect tests

    describe 'compile',
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] },
             vcap_services_context: { 'contrast-security' => [{ 'name' => 'test-contrast-security', 'label' => 'contrast-security',
                                                                'credentials' => { 'teamserver_url' => 'https://test.com', 'username' => 'aUser', 'api_key' => 'test', 'service_key' => 'test' } }] } do

      subject(:compiled) do
        contrast = ContrastSecurityAgent.new(context)
        contrast.detect
        contrast.compile
      end

      it 'should have a contrast security agent configuration file in the droplet' do
        compiled
        expect(File.exist?(File.join(app_dir, contrast_security_home, 'contrast.config'))).to eq(true)
      end

      it 'should create a contrast security home directory in the application root' do
        compiled
        expect(File.exist?(File.join(app_dir, contrast_security_home))).to eq(true)
      end

      describe 'download agent jar based on index.yml information' do
        it 'should download the agent with a matching key and jar version' do
          expect { compiled }.to output(%r{Downloading Contrast Security Agent #{version} from https://downloadsite/contrast-security/contrast-engine-#{version}.jar}).to_stdout
          expect(File.exist?(File.join(app_dir, contrast_security_home, jar_name))).to eq(true)
        end

        it 'should raise an error with original exception if the jar could not be downloaded',
           index_version: '0.0.0', index_uri: 'https://downloadsite/contrast-security/contrast-security-0.0.0.jar' do
          allow(LibertyBuildpack::Util).to receive(:download).and_raise('underlying download error')
          expect { compiled }.to raise_error(/Unable to download the Contrast Security Agent jar..+underlying download error/)
        end
      end
    end # end compile

    describe 'release',
             java_opts: [],
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] },
             vcap_services_context: { 'contrast-security' => [{ 'name' => 'test-contrast-security', 'label' => 'contrast-security',
                                                                'credentials' => { 'teamserver_url' => 'a', 'username' => 'a', 'api_key' => 'a', 'service_key' => 'c' } }] } do

      subject(:released) do
        contrast = ContrastSecurityAgent.new(context)
        contrast.detect
        contrast.release
      end

      it 'should return command line options for a valid service in a default container' do
        expect(released).to include("-javaagent:./#{contrast_security_home}/#{jar_name}=./#{contrast_security_home}/#{config_name}")
        expect(released).to include("-Dcontrast.dir=./#{contrast_security_home}")
        expect(released).to include('-Dcontrast.override.appname=TestApp')
      end

      it 'should return command line options for a valid service in a container with an adjusted relative location',
         common_paths: LibertyBuildpack::Container::CommonPaths.new do |example|

        example.metadata[:common_paths].relative_location = 'custom/container/dir'

        expect(released).to include("-javaagent:../../../#{contrast_security_home}/#{jar_name}=../../../#{contrast_security_home}/#{config_name}")
        expect(released).to include("-Dcontrast.dir=../../../#{contrast_security_home}")
        expect(released).to include('-Dcontrast.override.appname=TestApp')

      end
    end # end of release

  end
end # module

# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2016 the original author or authors.
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
require 'liberty_buildpack/framework/appdynamics_agent'
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Framework

  describe 'AppDynamicsAgent' do
    include_context 'component_helper' # component context

    # test data
    let(:appdynamics_home) { '.appdynamics_agent' } # the expected staged appdynamics agent directory
    let(:application_cache) { double('ApplicationCache') }
    let(:version) { '4.2.1_2' }
    let(:detect_string) { "app-dynamics-#{version}" }

    before do |example|
      # an index.yml entry returned from the index.yml of the appdynamics repository
      if example.metadata[:index_version]
        # appdynamics index.yml info provided by tests
        index_version = example.metadata[:index_version]
        index_uri = example.metadata[:index_uri]
      else
        # default values for the appdynamics index.yml info for tests
        index_version = version
        index_uri = 'https://downloadsite/appdynamics/app-dynamics.zip'
      end

      # By default, always stub the return of a valid index.yml entry
      find_item = example.metadata[:return_find_item].nil? ? true : example.metadata[:return_find_item]
      if find_item
        index_yml_entry = [LibertyBuildpack::Util::TokenizedVersion.new(index_version), index_uri]
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(index_yml_entry)
      else
        # tests can set find_item=false and a raise_error_message to mock a failed return of processing the index.yml
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_raise(example.metadata[:raise_error_message])
      end

      # For a download request of a appdynamics agent jar, return the fixture jar
      LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with(index_uri).and_yield(File.open('spec/fixtures/stub-app-dynamics-agent.zip'))
    end

    describe 'detect',
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] } do

      subject(:detected) { AppDynamicsAgent.new(context).detect }

      context 'user provided service' do
        def_type = 'servicetype'
        def_label = 'user-provided'
        def_tags = ['atag']
        def_credentials = { 'host-name' => '127.0.0.1' }

        it 'should be detected when the service name includes appdynamics substring',
           vcap_services_context: { def_type => [{ 'name' => 'appdynamics', 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }] } do
          expect(detected).to eq(detect_string)
        end

        it 'should be detected when the service name includes app-dynamics substring',
           vcap_services_context: { def_type => [{ 'name' => 'app-dynamics', 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }] } do
          expect(detected).to eq(detect_string)
        end

        it 'should not be detected when the service name includes app-dynamics substring but credentials do not have host-name',
           vcap_services_context: { def_type => [{ 'name' => 'app-dynamics', 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => { 'a' => 'b' } }] } do
          expect(detected).to eq(nil)
        end

      end

      context 'application with no services' do
        it 'should not detect the appdynamics service',
           vcap_services_context: {} do
          expect(detected).to eq(nil)
        end
      end

      context 'application with one service' do
        def_credentials = { 'host-name' => '127.0.0.1' }

        it 'should be detected when an application has a valid service attribute that includes appdynamics',
           vcap_services_context: { 'appdynamics' => [{ 'name' => 'test-appdynamics', 'label' => 'appdynamics',
                                                        'credentials' => def_credentials }] } do

          expect(detected).to eq(detect_string)
        end

        it 'should be detected when an application has a valid service attribute that includes app-dynamics',
           vcap_services_context: { 'app-dynamics' => [{ 'name' => 'test-appdynamics', 'label' => 'app-dynamics',
                                                         'credentials' => def_credentials }] } do

          expect(detected).to eq(detect_string)
        end

        it 'should not be detected when the service name includes app-dynamics substring but credentials do not have host-name',
           vcap_services_context: { 'app-dynamics' => [{ 'name' => 'test-appdynamics', 'label' => 'app-dynamics',
                                                         'credentials' => { 'a' => 'b' } }] } do
          expect(detected).to eq(nil)
        end

      end

      context 'invalid index.yml entry with a valid appdynamics service',
              vcap_services_context: { 'appdynamics' => [{ 'name' => 'test-appdynamics', 'label' => 'appdynamics',
                                                           'credentials' => { 'host-name' => '127.0.0.1' } }] } do

        it 'should raise an error including the underlying failure if the index.yml could not be processed',
           return_find_item: false, raise_error_message: 'underlying index.yml error' do
          expect(detected).to eq(nil)
        end

      end
    end # end of detect tests

    describe 'compile',
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] },
             vcap_services_context: { 'appdynamics' => [{ 'name' => 'test-appdynamics', 'label' => 'appdynamics',
                                                          'credentials' => { 'host-name' => '127.0.0.1' } }] } do

      subject(:compiled) do
        appdynamics = AppDynamicsAgent.new(context)
        appdynamics.detect
        appdynamics.compile
      end

      it 'should create a appdynamics home directory in the application root' do
        compiled
        expect(Dir.exist?(File.join(app_dir, appdynamics_home))).to eq(true)
      end

      describe 'download agent zip based on index.yml information' do
        it 'should download the agent with a matching key and jar version' do
          expect { compiled }.to output(%r{Downloading AppDynamics Agent #{version} from https://downloadsite/appdynamics/app-dynamics.zip}).to_stdout
          # jar file should not be there - just contents of it
          expect(File.exist?(File.join(app_dir, appdynamics_home, 'javaagent.jar'))).to eq(true)
        end

        it 'should raise an error with original exception if the jar could not be downloaded',
           index_version: '6.2.0_1238', index_uri: 'https://downloadsite/appdynamics/app-dynamics.zip' do
          allow(LibertyBuildpack::Util).to receive(:download_zip).and_raise('underlying download error')
          expect { compiled }.to raise_error(/Unable to download the AppDynamics Agent zip..+underlying download error/)
        end
      end
    end # end compile

    describe 'release',
             configuration: {},
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp',
                                         'application_uris' => ['TestApp.the.domain'] } do
      subject(:released) do
        appdynamics = AppDynamicsAgent.new(context)
        appdynamics.detect
        appdynamics.release
      end

      it 'should return command line options for a valid service in a default container',
         java_opts: [],
         vcap_services_context: { 'appdynamics' => [{ 'name' => 'test-appdynamics',
                                                      'label' => 'appdynamics',
                                                      'credentials' => { 'host-name' => '127.0.0.1' } }] } do
        java_opts = released
        expect(java_opts).to include("-javaagent:./#{appdynamics_home}/javaagent.jar")
        expect(java_opts).to include('-Dappdynamics.controller.hostName=127.0.0.1')
        expect(java_opts).to include('-Dappdynamics.agent.applicationName=TestApp')
        expect(java_opts).to include('-Dappdynamics.agent.tierName=TestApp')
        expect(java_opts).to include('-Dappdynamics.agent.nodeName=TestApp')
        expect(java_opts).not_to include('-Dappdynamics.controller.port=test-port')
        expect(java_opts).not_to include('-Dappdynamics.controller.ssl.enabled=test-ssl-enabled')
        expect(java_opts).not_to include('-Dappdynamics.agent.accountName=test-account-name')
        expect(java_opts).not_to include('-Dappdynamics.agent.accountAccessKey=test-account-access-key')
      end

      it 'should return command line options for a valid service with optional parameters',
         java_opts: [],
         vcap_services_context: { 'appdynamics' => [{ 'name' => 'test-appdynamics',
                                                      'label' => 'appdynamics',
                                                      'credentials' => { 'host-name' => '127.0.0.1',
                                                                         'tier-name' => 'another-test-tier-name',
                                                                         'application-name' => 'another-test-application-name',
                                                                         'node-name' => 'another-test-node-name',
                                                                         'port' => 'test-port',
                                                                         'ssl-enabled' => 'test-ssl-enabled',
                                                                         'account-name' => 'test-account-name',
                                                                         'account-access-key' => 'test-account-access-key' } }] } do
        java_opts = released
        expect(java_opts).to include("-javaagent:./#{appdynamics_home}/javaagent.jar")
        expect(java_opts).to include('-Dappdynamics.controller.hostName=127.0.0.1')
        expect(java_opts).to include('-Dappdynamics.agent.applicationName=another-test-application-name')
        expect(java_opts).to include('-Dappdynamics.agent.tierName=another-test-tier-name')
        expect(java_opts).to include('-Dappdynamics.agent.nodeName=another-test-node-name')
        expect(java_opts).to include('-Dappdynamics.controller.port=test-port')
        expect(java_opts).to include('-Dappdynamics.controller.ssl.enabled=test-ssl-enabled')
        expect(java_opts).to include('-Dappdynamics.agent.accountName=test-account-name')
        expect(java_opts).to include('-Dappdynamics.agent.accountAccessKey=test-account-access-key')
      end
    end # end of release
  end
end # module

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
require 'liberty_buildpack/framework/dynatrace_agent'
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Framework

  describe 'DynaTraceAgent' do
    include_context 'component_helper' # component context

    # test data
    let(:dynatrace_home) { '.dynatrace_agent' } # the expected staged dynatrace agent directory
    let(:application_cache) { double('ApplicationCache') }
    let(:version) { '6.2.0_1238' }
    let(:jar_name) { 'dynatrace-agent-unix.jar' }
    let(:detect_string) { "dynatrace-agent-#{version}" }

    before do |example|
      # an index.yml entry returned from the index.yml of the dynatrace repository
      if example.metadata[:index_version]
        # dynatrace index.yml info provided by tests
        index_version = example.metadata[:index_version]
        index_uri = example.metadata[:index_uri]
      else
        # default values for the dynatrace index.yml info for tests
        index_version = version
        index_uri = 'https://downloadsite/dynatrace/dynatrace-agent-unix.jar'
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

      # For a download request of a dynatrace agent jar, return the fixture jar
      LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with(index_uri).and_yield(File.open('spec/fixtures/stub-dynatrace-agent.jar'))
    end

    describe 'configuration' do
      it 'must have v6.2.0_1238 as the configured version' do
        configuration = YAML.load_file(File.expand_path('../../../config/dynatraceagent.yml', File.dirname(__FILE__)))

        expected_version = LibertyBuildpack::Util::TokenizedVersion.new('6.2.0_1238')
        actual_version = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration)[0]

        expect(actual_version).to eq(expected_version)
      end
    end

    describe 'detect',
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] } do

      subject(:detected) { DynaTraceAgent.new(context).detect }

      context 'user provided service' do
        def_type = 'servicetype'
        def_name = 'servicename'
        def_label = 'user-provided'
        def_tags = ['atag']
        def_credentials = { 'profile' => 'Monitoring', 'server' => '127.0.0.1' }

        it 'should be detected when the service name includes dynatrace substring',
           vcap_services_context: { def_type => [{ 'name' => 'dynatrace', 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }] } do
          expect(detected).to eq(detect_string)
        end

        it 'should raise a runtime error for multiple valid dynatrace user services',
           vcap_services_context: { def_type => [{ 'name' => 'dynatrace', 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }],
                                    'servicetype2' => [{ 'name' => 'dynatrace', 'label' => def_label, 'tags' => def_tags,
                                                         'credentials' => def_credentials }] } do

          expect { detected }.to raise_error(RuntimeError)
        end

        it 'should be detected when the tag includes dynatrace substring',
           vcap_services_context: { def_type => [{ 'name' => def_name, 'label' => def_label, 'tags' => ['dynatracetag'],
                                                   'credentials' => def_credentials }] } do
          expect(detected).to eq(detect_string)
        end

        it 'should not be detected unless the name or tag includes dynatrace substring',
           vcap_services_context: { def_type => [{ 'name' => def_name, 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }] } do
          expect(detected).to eq(nil)
        end
      end

      context 'application with no services' do
        it 'should not detect the dynatrace service',
           vcap_services_context: {} do
          expect(detected).to eq(nil)
        end
      end

      context 'application with one service' do
        def_credentials = { 'profile' => 'Monitoring', 'server' => '127.0.0.1' }

        it 'should be detected when an application has a valid service attribute that includes dynatrace',
           vcap_services_context: { 'dynatrace' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace',
                                                      'credentials' => def_credentials }] } do

          expect(detected).to eq(detect_string)
        end

        it 'should not be detected if dynatrace service does not exist',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-mysql', 'label' => 'mysql',
                                                  'credentials' => def_credentials }] } do

          expect(detected).to eq(nil)
        end

        it 'should not be detected since name is not used as a match check unless it is a user service',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-dynatrace', 'label' => 'mysql',
                                                  'credentials' => def_credentials }] } do

          expect(detected).to eq(nil)
        end
      end

      context 'application with multiple services' do
        def_credentials = { 'profile' => 'Monitoring', 'server' => '127.0.0.1' }

        it 'should be detected if one of the services is dynatrace',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-mysql', 'label' => 'mysql',
                                                  'credentials' => def_credentials }],
                                    'dynatrace' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace',
                                                      'credentials' => def_credentials }] } do

          expect(detected).to eq(detect_string)
        end

        it 'should raise a runtime error if multiple dynatrace services exist',
           vcap_services_context: { 'dynatracekey1' => [{ 'name' => 'test-name', 'label' => 'dynatrace',
                                                          'credentials' => def_credentials }],
                                    'dynatracekey2' => [{ 'name' => 'test-name', 'label' => 'dynatrace',
                                                          'credentials' => def_credentials }] } do

          expect { detected }.to raise_error(RuntimeError)
        end

        it 'should not be detected if none of the services is dynatrace',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-mysql', 'label' => 'mysql',
                                                  'credentials' => def_credentials }],
                                    'sqldb' => [{ 'name' => 'test-sqldb', 'label' => 'sqldb',
                                                  'credentials' => def_credentials }] } do

          expect(detected).to eq(nil)
        end
      end

      context 'invalid index.yml entry with a valid dynatrace service',
              vcap_services_context: { 'dynatrace' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace',
                                                         'credentials' => { 'profile' => 'Monitoring', 'server' => '127.0.0.1' } }] } do

        it 'should raise an error including the underlying failure if the index.yml could not be processed',
           return_find_item: false, raise_error_message: 'underlying index.yml error' do
          expect(detected).to eq(nil)
        end

      end

    end # end of detect tests

    describe 'compile',
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] },
             vcap_services_context: { 'dynatrace' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace',
                                                        'credentials' => { 'profile' => 'Monitoring', 'server' => '127.0.0.1' } }] } do

      subject(:compiled) do
        dynatrace = DynaTraceAgent.new(context)
        dynatrace.detect
        dynatrace.compile
      end

      it 'should create a dynatrace home directory in the application root' do
        compiled
        expect(File.exist?(File.join(app_dir, dynatrace_home))).to eq(true)
      end

      describe 'download agent jar based on index.yml information' do
        it 'should download the agent with a matching key and jar version' do
          expect { compiled }.to output(%r{Downloading Dynatrace Agent #{version} from https://downloadsite/dynatrace/dynatrace-agent-unix.jar}).to_stdout
          # jar file should not be there - just contents of it
          expect(File.exist?(File.join(app_dir, dynatrace_home, jar_name))).to eq(false)
          expect(File.exist?(File.join(app_dir, dynatrace_home, 'agent', 'linux-x86-64', 'agent', 'lib64', 'libdtagent.so'))).to eq(true)
        end

        it 'should raise an error with original exception if the jar could not be downloaded',
           index_version: '6.2.0_1238', index_uri: 'https://downloadsite/dynatrace/dynatrace-agent-unix.jar' do
          allow(LibertyBuildpack::Util).to receive(:download_zip).and_raise('underlying download error')
          expect { compiled }.to raise_error(/Unable to download the Dynatrace Agent jar..+underlying download error/)
        end
      end
    end # end compile

    describe 'release',
             java_opts: [],
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] },
             vcap_services_context: { 'dynatrace' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace',
                                                        'credentials' => { 'profile' => 'Monitoring', 'server' => '127.0.0.1' },
                                                        'options' => { 'exclude' => 'starts:somepackage.someclass' } }] } do

      subject(:released) do
        dynatrace = DynaTraceAgent.new(context)
        dynatrace.detect
        dynatrace.release
      end

      it 'should return command line options for a valid service in a default container' do
        pwd = ENV['PWD']
        pattern = "^(-agentpath:#{pwd}/app/#{dynatrace_home}/agent/.*/agent/.*/libdtagent.so=name=Monitoring,server=127.0.0.1.*)$"

        expect(released[0]).to match(/#{pattern}/)
      end

      it 'should return command line options for a valid service with optional parameters' do
        pwd = ENV['PWD']
        pattern = "^(-agentpath:#{pwd}/app/#{dynatrace_home}/agent/.*/agent/.*/libdtagent.so=name=Monitoring,server=127.0.0.1,exclude=starts:somepackage.someclass)$"

        expect(released[0]).to match(/#{pattern}/)
      end

    end # end of release

  end
end # module

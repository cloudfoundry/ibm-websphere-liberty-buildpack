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
require 'liberty_buildpack/framework/dynatrace_one_agent'
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Framework

  describe 'DynatraceOneAgent' do
    include_context 'component_helper' # component context

    # test data
    let(:dynatrace_home) { '.dynatrace_one_agent' } # the expected staged dynatrace one agent directory
    let(:application_cache) { double('ApplicationCache') }
    let(:version) { '1.95.0' }
    let(:jar_name) { 'dynatrace-one-agent.zip' }
    let(:detect_string) { 'dynatrace-one-agent-latest' }
    let(:download_url) { 'https://test-environmentid.live.dynatrace.com/api/v1/deployment/installer/agent/unix/paas/latest?include=java&bitness=64&Api-Token=test-apitoken' }

    before do |example|
      # For a download request of a dynatrace agent jar, return the fixture jar
      LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with(download_url).and_yield(File.open('spec/fixtures/stub-dynatrace-one-agent.zip'))
    end

    describe 'detect',
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] } do

      subject(:detected) { DynatraceOneAgent.new(context).detect }

      context 'user provided service' do
        def_type = 'servicetype'
        def_name = 'servicename'
        def_label = 'user-provided'
        def_tags = ['atag']
        def_credentials = { 'environmentid' => 'test-environmentid', 'apitoken' => 'test-apitoken' }

        it 'should not fail if service has no credentials',
           vcap_services_context: { def_type => [{ 'name' => 'dynatrace', 'label' => def_label }] } do

          expect(detected).to eq(nil)
        end

        it 'should be detected when the service name includes dynatrace substring and apitoken in credentials',
           vcap_services_context: { def_type => [{ 'name' => 'dynatrace', 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }] } do
          expect(detected).to eq(detect_string)
        end

        it 'should not do anything for multiple valid dynatrace user services',
           vcap_services_context: { def_type => [{ 'name' => 'dynatrace', 'label' => def_label, 'tags' => def_tags,
                                                   'credentials' => def_credentials }],
                                    'servicetype2' => [{ 'name' => 'dynatrace', 'label' => def_label, 'tags' => def_tags,
                                                         'credentials' => def_credentials }] } do

          expect(detected).to eq(nil)
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
        def_credentials = { 'environmentid' => 'test-environmentid', 'apitoken' => 'test-apitoken' }

        it 'should be detected when an application has a valid service attribute that includes dynatrace with apitoken',
           vcap_services_context: { 'dynatrace' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace', 'tags' => [],
                                                      'credentials' => def_credentials }] } do

          expect(detected).to eq(detect_string)
        end

        it 'should be detected when an application has exactly one service including environmentid and apitoken and a second one without',
           vcap_services_context: { 'user-provided' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace',
                                                          'credentials' => def_credentials },
                                                        { 'name' => 'test-dynatrace-tags', 'label' => 'dynatrace',
                                                          'credentials' => { 'tag:sometag' => 'value' } }] } do

          expect(detected).to eq(detect_string)
        end

        it 'should not be detected if dynatrace service does not exist',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-mysql', 'label' => 'mysql', 'tags' => [],
                                                  'credentials' => def_credentials }] } do

          expect(detected).to eq(nil)
        end

        it 'should not be detected since name is not used as a match check unless it is a user service',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-dynatrace', 'label' => 'mysql', 'tags' => [],
                                                  'credentials' => def_credentials }] } do

          expect(detected).to eq(nil)
        end
      end

      context 'application with multiple services' do
        def_credentials = { 'environmentid' => 'test-environmentid', 'apitoken' => 'test-apitoken' }

        it 'should be detected if one of the services is dynatrace',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-mysql', 'label' => 'mysql', 'tags' => [],
                                                  'credentials' => def_credentials }],
                                    'dynatrace' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace', 'tags' => [],
                                                      'credentials' => def_credentials }] } do

          expect(detected).to eq(detect_string)
        end

        it 'should do nothing if multiple dynatrace services exist',
           vcap_services_context: { 'dynatracekey1' => [{ 'name' => 'test-name', 'label' => 'dynatrace', 'tags' => [],
                                                          'credentials' => def_credentials }],
                                    'dynatracekey2' => [{ 'name' => 'test-name', 'label' => 'dynatrace', 'tags' => [],
                                                          'credentials' => def_credentials }] } do

          expect(detected).to eq(nil)
        end

        it 'should not be detected if none of the services is dynatrace',
           vcap_services_context: { 'mysql' => [{ 'name' => 'test-mysql', 'label' => 'mysql',
                                                  'credentials' => def_credentials }],
                                    'sqldb' => [{ 'name' => 'test-sqldb', 'label' => 'sqldb',
                                                  'credentials' => def_credentials }] } do

          expect(detected).to eq(nil)
        end
      end

    end # end of detect tests

    describe 'compile',
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] },
             vcap_services_context: { 'dynatrace' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace',
                                                        'credentials' => { 'environmentid' => 'test-environmentid', 'apitoken' => 'test-apitoken' } }] } do

      subject(:compiled) do
        dynatrace = DynatraceOneAgent.new(context)
        dynatrace.detect
        dynatrace.compile
      end

      it 'should create a dynatrace home directory in the application root' do
        compiled
        expect(File.exist?(File.join(app_dir, dynatrace_home))).to eq(true)
      end

      describe 'download agent zip based on service information' do
        it 'should download the agent and unpack it' do
          expect { compiled }.to output(%r{Downloading Dynatrace OneAgent latest from}).to_stdout
          # zip file should not be there - just contents of it
          expect(File.exist?(File.join(app_dir, dynatrace_home, jar_name))).to eq(false)
          expect(File.exist?(File.join(app_dir, dynatrace_home, 'agent', 'lib64', 'liboneagentloader.so'))).to eq(true)
          expect(File.exist?(File.join(app_dir, dynatrace_home, 'manifest.json'))).to eq(true)
        end

        it 'should raise an error with original exception if the zip could not be downloaded' do
          allow(LibertyBuildpack::Util).to receive(:download_zip).and_raise('underlying download error')
          expect { compiled }.to raise_error(/Unable to download the Dynatrace OneAgent..+underlying download error/)
        end
      end
    end # end compile

    describe 'release',
             java_opts: [],
             vcap_application_context: { 'application_version' => '12345678-a123-4b567-89c0-87654321abcde',
                                         'application_name' => 'TestApp', 'application_uris' => ['TestApp.the.domain'] },
             vcap_services_context: { 'dynatrace' => [{ 'name' => 'test-dynatrace', 'label' => 'dynatrace',
                                                        'credentials' => { 'environmentid' => 'test-environmentid', 'apitoken' => 'test-apitoken' } }] } do

      subject(:released) do
        dynatrace = DynatraceOneAgent.new(context)
        dynatrace.detect
        dynatrace.compile
        dynatrace.release
      end

      it 'should return command line options for a valid service in a default container' do
        expect(released[0]).to eq("-agentpath:#{ENV['PWD']}/app/#{dynatrace_home}/agent/lib64/liboneagentloader.so")
      end
    end # end of release

  end
end # module

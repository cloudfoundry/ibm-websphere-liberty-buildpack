# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2018 the original author or authors.
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
require 'liberty_buildpack/framework/ca_apm_agent'
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Framework

  describe 'CA APM Agent ' do
    include_context 'component_helper' # component context

    let(:ca_apm_home) { '.ca_apm' }
    let(:application_cache) { double('ApplicationCache') }
    let(:version) { '10.6.0_122' }
    let(:detect_string) { "introscope-agent-#{version}" }

    before do |example|

      # an index.yml entry returned from the index.yml of the ca apm repository
      if example.metadata[:index_version]
        index_version = example.metadata[:index_version]
        index_uri = example.metadata[:index_uri]

      # defaults
      else
        index_version = version
        index_uri = "https://ca.bintray.com/websphere/IntroscopeAgentFiles-NoInstaller#{version}websphere.unix.tar"
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

      # For a download request of a ca apm agent jar, return the fixture jar
      LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with(index_uri).and_yield(File.open('spec/fixtures/stub-ca-apm-agent.zip'))

    end

    describe 'detect',
             vcap_application_context: { 'application_version' => 'test-version',
                                         'application_name' => 'liberty_app',
                                         'application_uris' => ['liberty_app.example.com'] } do

      subject(:detected) { CAAPMAgent.new(context).detect }

      context 'user provided service' do
        def_type = 'servicetype'
        def_label = 'user-provided'
        def_tags = ['atag']
        def_credentials = { 'agent_manager_url' => 'localhost:5001' }

        it 'should be detected when the service name is introscope and agent_manager_url is present', vcap_services_context: { def_type =>
                                                   [{ 'name' => 'introscope',
                                                      'label' => def_label,
                                                      'tags' => def_tags,
                                                      'credentials' => def_credentials }] } do
          expect(detected).to eq(detect_string)
        end

        it 'should not be detected when the service name is anything besides introscope', vcap_services_context: { def_type =>
                                                   [{ 'name' => 'test-service-name',
                                                      'label' => def_label,
                                                      'tags' => def_tags,
                                                      'credentials' => def_credentials }] } do
          expect(detected).to eq(nil)
        end

        it 'should not be detected when the service name is intrscope but the agent_manager_url is missing', vcap_services_context: { def_type =>
                                                   [{ 'name' => 'test-service-name',
                                                      'label' => def_label,
                                                      'tags' => def_tags,
                                                      'credentials' => nil }] } do
          expect(detected).to eq(nil)
        end

        it 'should not be detected when the service name is intrscope but agent_manager_url key has typos',
           vcap_services_context: { def_type => [{ 'name' => 'test-service-name', 'label' => def_label, 'tags' => def_tags, 'credentials' => { 'agent-manager-url' => 'localhost' } }] } do
          expect(detected).to eq(nil)
        end
      end
    end

    describe 'compile', vcap_application_context: { 'application_version' => 'test-version',
                                                    'application_name' => 'liberty_app',
                                                    'application_uris' => ['liberty_app.example.com'] }, vcap_services_context: { 'introscope' =>
                                                                                                                                      [{ 'name' => 'introscope',
                                                                                                                                         'label' => 'introscope',
                                                                                                                                         'credentials' => { 'agent_manager_url' => 'localhost:5001' } }] } do

      subject(:compiled) do
        ca_apm = CAAPMAgent.new(context)
        ca_apm.detect
        ca_apm.compile
      end

      it 'should create a ca apm home directory in the application root' do
        compiled
        expect(Dir.exist?(File.join(app_dir, ca_apm_home))).to eq(true)
      end

      describe 'download agent tar based on index.yml' do
        it 'should download the agent tar based on the version key' do
          expect { compiled }.to output(%r{ Downloading CA APM Agent #{version} from https://ca.bintray.com/websphere/IntroscopeAgentFiles-NoInstaller#{version}websphere.unix.tar }).to_stdout
        end
      end
    end

    describe 'release', configuration: {}, vcap_application_context: { 'application_version' => 'test-version',
                                                                       'application_name' => 'liberty_app',
                                                                       'application_uris' => ['liberty_app.example.com'] } do
      subject(:released) do
        ca_apm = CAAPMAgent.new(context)
        ca_apm.detect
        ca_apm.release
      end

      it 'should return non nil java command line options for the introscope service',
         java_opts: [],
         vcap_services_context: { 'introscope' =>
                                     [{ 'name' => 'introscope',
                                        'label' => 'introscope',
                                        'credentials' => { 'agent_manager_url' => 'localhost:5001' } }] } do
        java_opts = released
        expect(java_opts).not_to eq(nil)
        expect(java_opts.size).to eq(9)
      end

      it 'should return java command line options for the introscope service',
         java_opts: [],
         vcap_services_context: { 'introscope' =>
                                     [{ 'name' => 'introscope',
                                        'label' => 'introscope',
                                        'credentials' => { 'agent_manager_url' => 'localhost:5001' } }] } do

        java_opts = released
        expect(java_opts).to include("-javaagent:./#{ca_apm_home}/wily/AgentNoRedefNoRetrans.jar")
        expect(java_opts).to include('-Dorg.osgi.framework.bootdelegation=com.wily.*')
        expect(java_opts).to include(/-Dcom.wily.introscope.agentProfile=.*\/wily\/core\/config\/IntroscopeAgent.NoRedef.profile/)
        expect(java_opts).to include('-Dintroscope.agent.hostName=liberty_app.example.com')
        expect(java_opts).to include('-Dintroscope.agent.agentName=liberty_app')
        expect(java_opts).to include('-DagentManager.url.1=localhost:5001')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=localhost')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=5001')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=com.wily.isengard.postofficehub.link.net.DefaultSocketFactory')
      end

      it 'should return java command line options for the introscope service and have the agent manager credential if present',
         java_opts: [],
         vcap_services_context: { 'introscope' =>
                                     [{  'name' => 'introscope',
                                         'label' => 'introscope',
                                         'credentials' => { 'agent_manager_url' => 'localhost:5001', 'agent_manager_credential' => 'test1234abcdf' } }] } do

        java_opts = released
        expect(java_opts).to include("-javaagent:./#{ca_apm_home}/wily/AgentNoRedefNoRetrans.jar")
        expect(java_opts).to include('-Dorg.osgi.framework.bootdelegation=com.wily.*')
        expect(java_opts).to include(/-Dcom.wily.introscope.agentProfile=.*\/wily\/core\/config\/IntroscopeAgent.NoRedef.profile/)
        expect(java_opts).to include('-Dintroscope.agent.hostName=liberty_app.example.com')
        expect(java_opts).to include('-Dintroscope.agent.agentName=liberty_app')
        expect(java_opts).to include('-DagentManager.url.1=localhost:5001')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=localhost')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=5001')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=com.wily.isengard.postofficehub.link.net.DefaultSocketFactory')
        expect(java_opts).to include('-DagentManager.credential=test1234abcdf')
      end
    end
  end
end

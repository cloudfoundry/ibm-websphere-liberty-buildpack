# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2015 the original author or authors.
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
require 'liberty_buildpack/framework/jrebel_agent'
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Framework

  describe 'JRebelAgent' do
    include_context 'component_helper' # component context

    # test data
    let(:jrebel_home) { '.jrebel' }
    let(:application_cache) { double('ApplicationCache') }
    let(:version) { '6.0.3' }
    let(:tokenized_version) { LibertyBuildpack::Util::TokenizedVersion.new(version) }

    before do |example|
      if example.metadata[:index_version]
        # JRebel index.yml info provided by tests
        index_version = example.metadata[:index_version]
        index_uri = example.metadata[:index_uri]
      else
        # default values for the JRebel index.yml info for tests
        index_version = version
        index_uri = "https://downloadsite/jrebel/jrebel-#{version}-nosetup.zip"
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

      # For a download request of a JRebel agent jar, return the fixture jar
      LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with(index_uri).and_yield(File.open('spec/fixtures/stub-jrebel-nosetup.zip'))
    end

    describe 'configuration' do
      it 'must have 6.0.3 as the configured version' do
        configuration = YAML.load_file(File.expand_path('../../../config/jrebelagent.yml', File.dirname(__FILE__)))
        expect(LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration)[0]).to eq(tokenized_version)
      end
    end

    describe 'detect' do
      it 'should not attach JRebel agent when no rebel-remote.xml in the application' do
        detected = JRebelAgent.new(
          app_dir: 'spec/fixtures/jrebel_test_app_no_rebel_remote',
          configuration: {}
        ).detect

        expect(detected).to be_nil
      end

      it 'should attach JRebel agent when rebel-remote.xml is in a WAR application' do
        detected = JRebelAgent.new(
          app_dir: 'spec/fixtures/jrebel_test_app_with_rebel_remote',
          configuration: {}
        ).detect

        expect(detected).to eq('jrebel-6.0.3')
      end

      it 'should attach JRebel agent when rebel-remote.xml is in an EAR application' do
        detected = JRebelAgent.new(
          app_dir: 'spec/fixtures/jrebel_test_ear_with_rebel_remote',
          configuration: {}
        ).detect

        expect(detected).to eq('jrebel-6.0.3')
      end

      it 'should attach JRebel agent when rebel-remote.xml is in a WAR application inside a packaged server' do
        detected = JRebelAgent.new(
          app_dir: 'spec/fixtures/jrebel_test_packaged_server_with_war_with_rebel_remote',
          configuration: {}
        ).detect

        expect(detected).to eq('jrebel-6.0.3')
      end

      it 'should attach JRebel agent when rebel-remote.xml is in an EAR application inside a packaged server' do
        detected = JRebelAgent.new(
          app_dir: 'spec/fixtures/jrebel_test_packaged_server_with_ear_with_rebel_remote',
          configuration: {}
        ).detect

        expect(detected).to eq('jrebel-6.0.3')
      end

      it 'should attach JRebel agent when rebel-remote.xml is in a WAR application inside a server directory' do
        detected = JRebelAgent.new(
          app_dir: 'spec/fixtures/jrebel_test_server_dir_with_war_with_rebel_remote',
          configuration: {}
        ).detect

        expect(detected).to eq('jrebel-6.0.3')
      end

      it 'should attach JRebel agent when rebel-remote.xml is in an EAR application inside a server directory' do
        detected = JRebelAgent.new(
          app_dir: 'spec/fixtures/jrebel_test_server_dir_with_ear_with_rebel_remote',
          configuration: {}
        ).detect

        expect(detected).to eq('jrebel-6.0.3')
      end

      it 'should not attach JRebel agent when disabled' do
        detected = JRebelAgent.new(
          app_dir: 'spec/fixtures/jrebel_test_app_with_rebel_remote',
          configuration: { 'enabled' => false }
        ).detect

        expect(detected).to be_nil
      end

    end # end of detect tests

    describe 'compile', configuration: {} do

      before do
        FileUtils.mkdir_p("#{app_dir}/WEB-INF/classes/")
        FileUtils.touch("#{app_dir}/WEB-INF/classes/rebel-remote.xml")
      end

      subject(:compiled) do
        jrebel = JRebelAgent.new(context)
        jrebel.detect
        jrebel.compile
      end

      it 'should create a JRebel home directory in the application root' do
        compiled
        expect(File.exist?(File.join(app_dir, jrebel_home))).to eq(true)
      end

      describe 'download JRebel agent jar based on index.yml information' do
        it 'should download the agent with a matching key and jar version' do
          expect { compiled }.to output(%r{Downloading JRebel Agent #{version} from https://downloadsite/jrebel/jrebel-#{version}-nosetup.zip}).to_stdout
          expect(File.exist?(File.join(app_dir, jrebel_home, 'jrebel', 'lib', 'libjrebel64.so'))).to eq(true)
        end

        it 'should raise an error with original exception if the jar could not be downloaded',
           index_version: '6.0.3', index_uri: 'https://downloadsite/jrebel/jrebel-6.0.3-nosetup.zip' do
          allow(LibertyBuildpack::Util).to receive(:download_zip).and_raise('underlying download error')
          expect { compiled }.to raise_error(/Unable to download the JRebel zip\. Ensure that the zip at..+underlying download error/)
        end
      end
    end # end compile

    describe 'release', java_opts: [], configuration: {} do

      subject(:released) do
        jrebel = JRebelAgent.new(context)
        jrebel.detect
        jrebel.release
        context[:java_opts]
      end

      it 'should return command line options for a valid service in a default container',
         java_opts: [] do
        java_opts = released
        expect(java_opts).to include('-agentpath:./.jrebel/jrebel/lib/libjrebel64.so')
        expect(java_opts).to include('-Xshareclasses:none')
        expect(java_opts).to include('-Drebel.remoting_plugin=true')
        expect(java_opts).to include('-Drebel.redefine_class=false')
        expect(java_opts).to include('-Drebel.log=true')
        expect(java_opts).to include('-Drebel.log.file=./../logs/jrebel.log')
        expect(java_opts).to include('-Drebel.cloud.platform=cloudfoundry/ibm-websphere-liberty-buildpack')
      end

      it 'should return command line options for a valid service in a default container with openjdk',
         java_opts: [], jvm_type: 'openjdk' do
        java_opts = released
        expect(java_opts).to include('-agentpath:./.jrebel/jrebel/lib/libjrebel64.so')
        expect(java_opts).not_to include('-Xshareclasses:none')
        expect(java_opts).to include('-Drebel.remoting_plugin=true')
        expect(java_opts).not_to include('-Drebel.redefine_class=false')
        expect(java_opts).to include('-Drebel.log=true')
        expect(java_opts).to include('-Drebel.log.file=./../logs/jrebel.log')
        expect(java_opts).to include('-Drebel.cloud.platform=cloudfoundry/ibm-websphere-liberty-buildpack')
      end

      it 'should return command line options for a valid service in a container with an adjusted relative location',
         java_opts: [], common_paths: LibertyBuildpack::Container::CommonPaths.new do |example|
        example.metadata[:common_paths].relative_location = 'custom/container/dir'

        java_opts = released
        expect(java_opts).to include('-agentpath:../../../.jrebel/jrebel/lib/libjrebel64.so')
        expect(java_opts).to include('-Xshareclasses:none')
        expect(java_opts).to include('-Drebel.remoting_plugin=true')
        expect(java_opts).to include('-Drebel.redefine_class=false')
        expect(java_opts).to include('-Drebel.log=true')
        expect(java_opts).to include('-Drebel.log.file=../../../../logs/jrebel.log')
        expect(java_opts).to include('-Drebel.cloud.platform=cloudfoundry/ibm-websphere-liberty-buildpack')
      end
    end # end of release
  end
end

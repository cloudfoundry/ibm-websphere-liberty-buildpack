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
require 'liberty_buildpack/framework/dynamic_pulse_agent'
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Framework

  describe 'DynamicPULSEAgent' do
    include_context 'component_helper' # component context

    let(:remote_dir) { File.expand_path('../../fixtures/dynamicpulse-remote', File.dirname(__FILE__)) }
    let(:app_dir) { File.join(remote_dir, 'app') }
    let(:webinf_dir) { File.join(app_dir, 'WEB-INF') }
    let(:application_cache) { double('ApplicationCache') }
    let(:lib_directory) { File.join(webinf_dir, 'lib') }

    before do |example|
      # default values for the new relic index.yml info for tests
      index_uri = 'http://downloadsite/dynamicpulse/SampleWebApp/dynamicpulse-agent.zip'

      # tests can set find_item=false and a raise_error_message to mock a failed return of processing the index.yml
      LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_raise(example.metadata[:raise_error_message])

      # For a download request of a new relic agent jar, return the fixture jar
      LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with(index_uri).and_yield(File.open('spec/fixtures/stub-dynamic-pulse-agent.zip'))

      FileUtils.mkdir_p(lib_directory)
    end

    describe 'configuration' do
      it 'must have url and systemId' do
        FileUtils.cp(File.join(remote_dir, 'dynamicpulse-remote.xml'), File.join(webinf_dir, 'dynamicpulse-remote.xml'))
        dynamicpulse_remote_xml = File.join(webinf_dir, 'dynamicpulse-remote.xml')
        doc = REXML::Document.new(open(dynamicpulse_remote_xml))
        url = doc.elements['dynamicpulse-remote/centerUrl'].text

        expect(url).to eq('http://downloadsite/dynamicpulse/')
      end

      it 'must have url and systemId' do
        FileUtils.cp(File.join(remote_dir, 'dynamicpulse-remote.xml'), File.join(webinf_dir, 'dynamicpulse-remote.xml'))
        dynamicpulse_remote_xml = File.join(webinf_dir, 'dynamicpulse-remote.xml')
        doc = REXML::Document.new(open(dynamicpulse_remote_xml))
        system_id = doc.elements['dynamicpulse-remote/systemId'].text

        expect(system_id).to eq('SampleWebApp')
      end
    end

    describe 'detect' do
      subject(:detected) do
        dynamicpulse = DynamicPULSEAgent.new(app_dir: app_dir, lib_directory: lib_directory)
        dynamicpulse.detect
      end

      it 'should be detected when the dynamicpulse-remote.xml is valid' do
        FileUtils.cp(File.join(remote_dir, 'dynamicpulse-remote.xml'), File.join(webinf_dir, 'dynamicpulse-remote.xml'))
        expect(detected).to eq('DynamicPULSE-3.+')
      end

      it 'should not be detected if the dynamicpulse-remote.xml is nothing' do
        expect(detected).to eq(nil)
      end

      it 'should raise an error with ParseException if xml file is illegal format' do
        FileUtils.cp(File.join(remote_dir, 'dynamicpulse-remote_illegalFormat.xml'), File.join(webinf_dir, 'dynamicpulse-remote.xml'))
        expect { detected }.to raise_error(REXML::ParseException)
      end
    end

    describe 'compile' do
      subject(:compiled) do
        dynamicpulse = DynamicPULSEAgent.new(app_dir: app_dir, lib_directory: lib_directory)
        dynamicpulse.detect
        dynamicpulse.compile
      end

      it 'should create a dynamicpulse home directory in the application root' do
        FileUtils.cp(File.join(remote_dir, 'dynamicpulse-remote.xml'), File.join(webinf_dir, 'dynamicpulse-remote.xml'))
        compiled
        expect(File.exist?(File.join(app_dir, '.dynamic_pulse_agent'))).to eq(true)
      end

      it 'should download the agent with a matching centerUrl and systemId' do
        FileUtils.cp(File.join(remote_dir, 'dynamicpulse-remote.xml'), File.join(webinf_dir, 'dynamicpulse-remote.xml'))
        expect { compiled }.to output(%r{Downloading DynamicPULSE Agent 3.+ from http://downloadsite/dynamicpulse/SampleWebApp/dynamicpulse-agent.zip}).to_stdout
        # zip file should not be there - just contents of it
        expect(File.exist?(File.join(app_dir, '.dynamic_pulse_agent', 'dynamicpulse-agent.zip'))).to eq(false)
      end

      it 'should raise an error if the illegal centerUrl is in the dynamicpulse-remote.xml' do
        FileUtils.cp(File.join(remote_dir, 'dynamicpulse-remote_illegalCenterUrl.xml'), File.join(webinf_dir, 'dynamicpulse-remote.xml'))
        allow(LibertyBuildpack::Util).to receive(:download_zip).and_raise('underlying download error')
        expect { compiled }.to raise_error(/Can't download dynamicpulse-agent.zip from..+underlying download error/)
      end

      it 'should raise an error if the centerUrl is not in the dynamicpulse-remote.xml' do
        FileUtils.cp(File.join(remote_dir, 'dynamicpulse-remote_notCenterUrl.xml'), File.join(webinf_dir, 'dynamicpulse-remote.xml'))
        dynamicpulse = DynamicPULSEAgent.new(app_dir: app_dir, lib_directory: lib_directory)
        expect { dynamicpulse.compile }.to raise_error(/url , or systemId  is not available, detect needs to be invoked/)
      end
    end

    describe 'release' do
      subject(:released) do
        dynamicpulse = DynamicPULSEAgent.new(app_dir: app_dir, lib_directory: lib_directory, java_opts: [])
        dynamicpulse.detect
        dynamicpulse.compile
        dynamicpulse.release
      end

      it 'should return command line options for a valid service in a default container' do
        FileUtils.cp(File.join(remote_dir, 'dynamicpulse-remote.xml'), File.join(webinf_dir, 'dynamicpulse-remote.xml'))
        expect(released).to include('-javaagent:/home/vcap/app/.dynamic_pulse_agent/aspectjweaver.jar')
        expect(released).to include('-Dorg.aspectj.tracing.factory=default')
      end
    end
  end
end # module

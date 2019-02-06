# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013-2014 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'spec_helper'
require 'console_helper'
require 'fileutils'
require 'liberty_buildpack/jre/openjdk'
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Jre

  describe OpenJdk do
    include_context 'console_helper'

    let(:version_8) { VERSION_8 = LibertyBuildpack::Util::TokenizedVersion.new('1.8.0_+') }

    let(:version_7) { VERSION_7 = LibertyBuildpack::Util::TokenizedVersion.new('1.7.0_+') }

    let(:configuration) do
      { 'memory_sizes' => { 'metaspace' => '64m..',
                            'permgen'   => '64m..' },
        'memory_heuristics' => { 'heap'      => '75',
                                 'metaspace' => '10',
                                 'permgen'   => '10',
                                 'stack'     => '5',
                                 'native' => '10' } }
    end

    let(:application_cache) { double('ApplicationCache') }

    before do
      allow(LibertyBuildpack::Repository::ConfiguredItem).to receive(:find_item).and_return([version_7, 'test-uri'])
    end

    it 'should detect with id of openjdk-<version>' do
      Dir.mktmpdir do |root|
        detected = OpenJdk.new(
          app_dir: '',
          java_home: '',
          java_opts: [],
          configuration: configuration,
          license_ids: {},
          jvm_type: 'openjdk'
        ).detect

        expect(detected).to eq("openjdk-#{version_7}")
      end
    end

    it 'should extract Java from a GZipped TAR' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))

        OpenJdk.new(
          app_dir: root,
          configuration: configuration,
          java_home: '',
          java_opts: [],
          license_ids: {}
        ).compile

        java = File.join(root, '.java', 'jre', 'bin', 'java')
        expect(File.exist?(java)).to eq(true)
      end
    end

    it 'adds the JAVA_HOME to java_home' do
      Dir.mktmpdir do |root|
        java_home = ''

        OpenJdk.new(
          app_dir: '/application-directory',
          java_home: java_home,
          java_opts: [],
          configuration: configuration,
          license_ids: {}
        )

        expect(java_home).to eq('.java')
      end
    end

    it 'should add the heuristics file with default configuration' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))

        component = OpenJdk.new(
          app_dir: root,
          configuration: configuration,
          java_home: '',
          java_opts: [],
          license_ids: {}
        )
        component.release

        my_app_dir = component.instance_variable_get('@app_dir')
        memory_config = File.read("#{my_app_dir}/.memory_config/heuristics")
        expect(memory_config).to include('heap')
      end
    end

    it 'should add the sizes file with default configuration' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))

        component = OpenJdk.new(
          app_dir: root,
          configuration: configuration,
          java_home: '',
          java_opts: [],
          license_ids: {}
        )
        component.release

        my_app_dir = component.instance_variable_get('@app_dir')
        memory_config = File.read("#{my_app_dir}/.memory_config/sizes")
        expect(memory_config).to include('permgen')
      end
    end

    it 'should fail when ConfiguredItem.find_item fails' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_raise('test error')
        expect do
          OpenJdk.new(
            app_dir: '',
            java_home: '',
            java_opts: [],
            configuration: configuration,
            license_ids: {},
            jvm_type: 'openjdk'
          ).detect
        end.to raise_error(/OpenJdk\ error:\ test\ error/)
      end
    end

    it 'adds OnOutOfMemoryError to java_opts' do
      Dir.mktmpdir do |root|
        java_opts = []

        OpenJdk.new(
          app_dir: root,
          java_home: '',
          java_opts: java_opts,
          common_paths: LibertyBuildpack::Container::CommonPaths.new,
          configuration: configuration,
          license_ids: {}
        ).release

        expect(java_opts).to include("-XX:OnOutOfMemoryError=./#{LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{OpenJdk::KILLJAVA_FILE_NAME}")
      end
    end

    it 'places the killjava script (with appropriately substituted content) in the diagnostics directory' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))

        OpenJdk.new(
          app_dir: root,
          configuration: configuration,
          java_home: '',
          java_opts: [],
          license_ids: {}
        ).compile

        expect(Pathname.new(File.join(LibertyBuildpack::Diagnostics.get_diagnostic_directory(root), OpenJdk::KILLJAVA_FILE_NAME))).to exist
      end
    end
  end

end

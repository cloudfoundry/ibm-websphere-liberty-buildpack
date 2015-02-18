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
require 'fileutils'
require 'liberty_buildpack/jre/openjdk'
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Jre

  describe OpenJdk do

    OPENJDK_DETAILS_PRE_8 = [LibertyBuildpack::Util::TokenizedVersion.new('1.7.0'), 'test-uri']
    OPENJDK_DETAILS_POST_8 = [LibertyBuildpack::Util::TokenizedVersion.new('1.8.0'), 'test-uri']

    let(:application_cache) { double('ApplicationCache') }
    let(:memory_heuristic) { double('MemoryHeuristic', resolve: %w(opt-1 opt-2)) }

    before do
      allow(LibertyBuildpack::Jre::WeightBalancingMemoryHeuristic).to receive(:new).and_return(memory_heuristic)
      @config = { 'repository_root' => 'http://dummyurl', 'version' => '1.0.1_+' }
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    after do
      $stdout = STDOUT
      $stderr = STDERR
      ENV['LBP_OPENJDK_VERSION'] = nil
    end

    context 'detect' do

      it 'should not detect if openjdk is not set as jvm type' do
        Dir.mktmpdir do |root|
          LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).and_yield(File.open('spec/fixtures/test-versions.yml'))

          detected = OpenJdk.new(
              app_dir: '',
              java_home: '',
              java_opts: [],
              configuration: @config,
              license_ids: {},
              jvm_type: nil
          ).detect

          expect(detected).to be_nil
        end
      end

      it 'should not detect if openjdk is not set as jvm type due to input error' do
        Dir.mktmpdir do |root|
          LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).and_yield(File.open('spec/fixtures/test-versions.yml'))

          detected = OpenJdk.new(
              app_dir: '',
              java_home: '',
              java_opts: [],
              configuration: @config,
              license_ids: {},
              jvm_type: 'openjdk1'
          ).detect

          expect(detected).to be_nil
        end
      end
      it 'should return latest version of the default release when no version is specified' do
        Dir.mktmpdir do |root|
          LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).and_yield(File.open('spec/fixtures/test-versions.yml'))

          detected = OpenJdk.new(
              app_dir: '',
              java_home: '',
              java_opts: [],
              configuration: @config,
              license_ids: {},
              jvm_type: 'openjdk'
          ).detect

          expect(detected).to eq('openjdk-1.0.1_05')
        end
      end

      it 'overrides version with an env var' do
        Dir.mktmpdir do |root|
          LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).and_yield(File.open('spec/fixtures/test-versions.yml'))
          ENV['LBP_OPENJDK_VERSION'] = '1.2.+'

          detected = OpenJdk.new(
              app_dir: '',
              java_home: '',
              java_opts: [],
              configuration: @config,
              license_ids: {},
              jvm_type: 'openjdk'
          ).detect

          expect(detected).to eq('openjdk-1.2.0_02')
        end
      end

      it 'should fail when ConfiguredItem.find_item fails' do
        Dir.mktmpdir do |root|
          expect do
            OpenJdk.new(
              app_dir: '',
              java_home: '',
              java_opts: [],
              configuration: {},
              license_ids: {},
              jvm_type: 'openjdk'
            ).detect
          end.to raise_error(/OpenJdk\ error:/)
        end
      end

    end # context detect

    it 'should extract Java from a GZipped TAR' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(OPENJDK_DETAILS_PRE_8)
        LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))

        OpenJdk.new(
            app_dir: root,
            configuration: {},
            java_home: '',
            java_opts: [],
            license_ids: {}
        ).compile

        java = File.join(root, '.java', 'jre', 'bin', 'java')
        expect(File.exists?(java)).to eq(true)
      end
    end

    it 'adds the JAVA_HOME to java_home' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(OPENJDK_DETAILS_PRE_8)

        java_home = ''
        OpenJdk.new(
            app_dir: '/application-directory',
            java_home: java_home,
            java_opts: [],
            configuration: {},
            license_ids: {}
        )

        expect(java_home).to eq('.java')
      end
    end

    it 'should add memory options to java_opts' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(OPENJDK_DETAILS_PRE_8)

        java_opts = %w(test-opt-2 test-opt-1)
        OpenJdk.new(
            app_dir: root,
            java_home: '',
            java_opts: java_opts,
            configuration: {},
            license_ids: {}
        ).release

        expect(java_opts).to include('opt-1')
        expect(java_opts).to include('opt-2')
      end
    end

    it 'adds OnOutOfMemoryError to java_opts' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(OPENJDK_DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
            app_dir: root,
            java_home: '',
            java_opts: java_opts,
            common_paths: LibertyBuildpack::Container::CommonPaths.new,
            configuration: {},
            license_ids: {}
        ).release

        expect(java_opts).to include("-XX:OnOutOfMemoryError=./#{LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{OpenJdk::KILLJAVA_FILE_NAME}")
      end
    end

    it 'places the killjava script (with appropriately substituted content) in the diagnostics directory' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(OPENJDK_DETAILS_PRE_8)
        LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))

        OpenJdk.new(
            app_dir: root,
            configuration: {},
            java_home: '',
            java_opts: [],
            license_ids: {}
        ).compile

        expect(Pathname.new(File.join(LibertyBuildpack::Diagnostics.get_diagnostic_directory(root), OpenJdk::KILLJAVA_FILE_NAME))).to exist
      end
    end
  end

end

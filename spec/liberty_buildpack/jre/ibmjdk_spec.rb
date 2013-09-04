# Encoding: utf-8
# IBM Liberty Buildpack
# Copyright 2013 the original author or authors.
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
require 'liberty_buildpack/jre/ibmjdk'

module LibertyBuildpack::Jre

  describe IBMJdk do

    DETAILS_PRE_8 = [LibertyBuildpack::Util::TokenizedVersion.new('1.7.0'), 'test-uri']
    DETAILS_POST_8 = [LibertyBuildpack::Util::TokenizedVersion.new('1.8.0'), 'test-uri']

    let(:application_cache) { double('ApplicationCache') }
    let(:memory_heuristic) { double('MemoryHeuristic', resolve: %w(opt-1 opt-2)) }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with id of ibmjdk-<version>' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        detected = IBMJdk.new(
            app_dir: '',
            java_home: '',
            java_opts: [],
            configuration: {}
        ).detect

        expect(detected).to eq('ibmjdk-1.7.0')
      end
    end

    it 'should extract Java from a GZipped TAR' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))

        IBMJdk.new(
            app_dir: root,
            configuration: {},
            java_home: '',
            java_opts: []
        ).compile

        java = File.join(root, '.java', 'jre', 'bin', 'java')
        expect(File.exists?(java)).to be_true
      end
    end

    it 'adds the JAVA_HOME to java_home' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_home = ''
        IBMJdk.new(
            app_dir: '/application-directory',
            java_home: java_home,
            java_opts: [],
            configuration: {}
        )

        expect(java_home).to eq('.java')
      end
    end

    it 'should fail when ConfiguredItem.find_item fails' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_raise('test error')
        expect do
          IBMJdk.new(
              app_dir: '',
              java_home: '',
              java_opts: [],
              configuration: {}
          ).detect
        end.to raise_error(/IBM\ JRE\ error:\ test\ error/)
      end
    end

    it 'should add memory options to java_opts' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        ENV['MEMORY_LIMIT'] = nil

        java_opts = []
        IBMJdk.new(
            app_dir: '/application-directory',
            java_home: '',
            java_opts: java_opts,
            configuration: {}
        ).release

        expect(java_opts).to include('-Xnocompressedrefs')
        expect(java_opts).to include('-Xtune:virtualized')
      end
    end

    it 'should add extra memory options when a memory limit is set' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        ENV['MEMORY_LIMIT'] = '512m'

        java_opts = []
        IBMJdk.new(
            app_dir: '/application-directory',
            java_home: '',
            java_opts: java_opts,
            configuration: {}
        ).release

        expect(java_opts).to include('-Xtune:virtualized')
        expect(java_opts).to include('-Xmx384M')
      end
    end

    it 'should used -Xnocompressedrefs when the memory limit is less than 256m' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        ENV['MEMORY_LIMIT'] = '64m'

        java_opts = []
        IBMJdk.new(
            app_dir: '/application-directory',
            java_home: '',
            java_opts: java_opts,
            configuration: {}
        ).release

        expect(java_opts).to include('-Xtune:virtualized')
        expect(java_opts).to include('-Xmx48M')
        expect(java_opts).to include('-Xnocompressedrefs')
      end
    end

    it 'adds OnOutOfMemoryError to java_opts' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        IBMJdk.new(
            app_dir: root,
            java_home: '',
            java_opts: java_opts,
            configuration: {}
        ).release

        expect(java_opts).to include("-XX:OnOutOfMemoryError=./#{LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{IBMJdk::KILLJAVA_FILE_NAME}")
      end
    end

    it 'places the killjava script (with appropriately substituted content) in the diagnostics directory' do
      Dir.mktmpdir do |root|
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))

        java_opts = []
        IBMJdk.new(
            app_dir: root,
            java_home: '',
            java_opts: java_opts,
            configuration: {}
        ).compile

        killjava_content = File.read(File.join(LibertyBuildpack::Diagnostics.get_diagnostic_directory(root), IBMJdk::KILLJAVA_FILE_NAME))
        expect(killjava_content).to include("#{LibertyBuildpack::Diagnostics::LOG_FILE_NAME}")
      end
    end

  end

end

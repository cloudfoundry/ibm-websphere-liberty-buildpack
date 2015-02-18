# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
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
require 'liberty_buildpack/repository/configured_item'

module LibertyBuildpack::Repository

  describe ConfiguredItem do

    context 'base tests' do

    RESOLVED_VERSION = 'resolved-version'
    RESOLVED_URI = 'resolved-uri'
    VERSION_KEY = 'version'
    REPOSITORY_ROOT_KEY = 'repository_root'
    RESOLVED_ROOT = 'resolved-root'

    before do
      LibertyBuildpack::Repository::RepositoryIndex.stub(:new).and_return(double('repository index', find_item: [RESOLVED_VERSION, RESOLVED_URI]))
    end

    it 'raises an error if no repository root is specified' do
      expect { ConfiguredItem.find_item({}) }.to raise_error
    end

    it 'resolves a system.properties version if specified' do
      details = ConfiguredItem.find_item(
        'repository_root' => 'test-repository-root',
        'java.runtime.version' => 'test-java-runtime-version',
        'version' => '1.7.0'
      )

      expect(details[0]).to eq(RESOLVED_VERSION)
      expect(details[1]).to eq(RESOLVED_URI)
    end

    it 'resolves a configuration version if specified' do
      details = ConfiguredItem.find_item(
        'repository_root' => 'test-repository-root',
        'version' => '1.7.0'
      )

      expect(details[0]).to eq(RESOLVED_VERSION)
      expect(details[1]).to eq(RESOLVED_URI)
    end

    it 'drives the version validator block if supplied' do
      ConfiguredItem.find_item(
        'repository_root' => 'test-repository-root',
        'version' => '1.7.0'
      ) do |version|
        expect(version).to eq(LibertyBuildpack::Util::TokenizedVersion.new('1.7.0'))
      end
    end

    it 'resolves nil if no version is specified' do
      details = ConfiguredItem.find_item(
        'repository_root' => 'test-repository-root'
      )

      expect(details[0]).to eq(RESOLVED_VERSION)
      expect(details[1]).to eq(RESOLVED_URI)
    end

    end # base tests

    context 'version resolution' do
      let(:application_cache) { double('ApplicationCache') }

      before do
        LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).and_yield(File.open('spec/fixtures/test-versions.yml'))
      end

      after do
        ENV['LBP_DUMMY_VERSION'] = nil
      end

      it 'resolves proper match when env var is not set' do
        details = ConfiguredItem.find_item(
          'repository_root' => 'test-repository-root',
          'version' => '1.1.0'
        )
        expect(details[0]).to eq(%w(1 1 0 02))
      end

      it 'resolves when env var specifies latest' do
        ENV['LBP_DUMMY_VERSION'] = '+'
        details = ConfiguredItem.find_item(
          'repository_root' => 'test-repository-root',
          'version' => '1.1.0',
          'class_name' => 'DUMMY'
        )
        expect(details[0]).to eq(%w(2 0 0 01))
      end

      it 'resolves when env var specifies major.+' do
        ENV['LBP_DUMMY_VERSION'] = '1.+'
        details = ConfiguredItem.find_item(
          'repository_root' => 'test-repository-root',
          'version' => '1.1.0',
          'class_name' => 'DUMMY'
        )
        expect(details[0]).to eq(%w(1 2 0 02))
      end

      it 'should fail if minor is not specified' do
        ENV['LBP_DUMMY_VERSION'] = '1'
        expect do
          ConfiguredItem.find_item(
            'repository_root' => 'test-repository-root',
            'version' => '1.1.0',
            'class_name' => 'DUMMY'
          )
        end.to raise_error(RuntimeError)
      end

      it 'resolves when env_var specifies major.minor.+' do
        ENV['LBP_DUMMY_VERSION'] = '1.0.+'
        details = ConfiguredItem.find_item(
          'repository_root' => 'test-repository-root',
          'version' => '1.2.0',
          'class_name' => 'DUMMY'
        )
        expect(details[0]).to eq(%w(1 0 1 05))
      end

      it 'resolves when env_var specifies major.minor.micro' do
        ENV['LBP_DUMMY_VERSION'] = '1.0.0'
        details = ConfiguredItem.find_item(
          'repository_root' => 'test-repository-root',
          'version' => '1.1.0',
          'class_name' => 'DUMMY'
        )
        expect(details[0]).to eq(%w(1 0 0 03))
      end

      it 'should fail if micro is not specified' do
        ENV['LBP_DUMMY_VERSION'] = '1.0'
        expect do
          ConfiguredItem.find_item(
            'repository_root' => 'test-repository-root',
            'version' => '1.1.0',
            'class_name' => 'DUMMY'
          )
        end.to raise_error(RuntimeError)
      end

      it 'resolves when env_var specifies major.minor.micro.+' do
        ENV['LBP_DUMMY_VERSION'] = '1.0.0_+'
        details = ConfiguredItem.find_item(
          'repository_root' => 'test-repository-root',
          'version' => '1.1.0',
          'class_name' => 'DUMMY'
        )
        expect(details[0]).to eq(%w(1 0 0 03))
      end

      it 'resolves when env_var specifies major.minor.micro_qualifier' do
        ENV['LBP_DUMMY_VERSION'] = '1.0.0_02'
        details = ConfiguredItem.find_item(
          'repository_root' => 'test-repository-root',
          'version' => '1.1.0',
          'class_name' => 'DUMMY'
        )
        expect(details[0]).to eq(%w(1 0 0 02))
      end

      it 'should fail if micro does not exist' do
        ENV['LBP_DUMMY_VERSION'] = '1.0.5'
        expect do
          ConfiguredItem.find_item(
            'repository_root' => 'test-repository-root',
            'version' => '1.1.0',
            'class_name' => 'DUMMY'
          )
        end.to raise_error(RuntimeError)
      end

    end

  end

end

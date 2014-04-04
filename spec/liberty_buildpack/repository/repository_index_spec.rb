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
require 'liberty_buildpack/util/cache/download_cache'
require 'liberty_buildpack/repository/repository_index'

module LibertyBuildpack::Repository

  describe RepositoryIndex do

    let(:application_cache) { double('ApplicationCache') }

    it 'should load index with license' do
      LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with('test-uri/index.yml')
      .and_yield(File.open('spec/fixtures/test-index.yml'))
      VersionResolver.stub(:resolve).with('test-version', %w(resolved-version)).and_return('resolved-version')

      repository_index = RepositoryIndex.new('test-uri')
      expect(repository_index.find_item('test-version')).to eq(%w(resolved-version resolved-uri resolved-license))
    end

    it 'should load index without license' do
      LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with('test-uri/index.yml')
      .and_yield(File.open('spec/fixtures/test-index-orig.yml'))
      VersionResolver.stub(:resolve).with('test-version', %w(resolved-version)).and_return('resolved-version')

      repository_index = RepositoryIndex.new('test-uri')
      expect(repository_index.find_item('test-version')).to eq(['resolved-version', 'resolved-uri', nil])
    end
  end

end

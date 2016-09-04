# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
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
require 'liberty_buildpack/repository/component_index'
require 'liberty_buildpack/util/cache/download_cache'

module LibertyBuildpack::Repository

  describe ComponentIndex do

    let(:application_cache) { double('ApplicationCache') }

    it 'should return nil to the caller if the file is not a component_index.yml' do
      component_index = ComponentIndex.new('resolved-uri')
      expect(component_index.components).to eq(nil)
    end

    it 'should return a hash of component names to URIs listed in the component index if the argument is a valid component_index.yml' do
      LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with('test-uri/component_index.yml')
                       .and_yield(File.open('spec/fixtures/test-component-index.yml'))

      component_index = ComponentIndex.new('test-uri/component_index.yml')
      expect(component_index.components).to eq(
        'resolved-component1' => 'resolved-component1-uri',
        'resolved-component2' => 'resolved-component2-uri'
      )
    end
  end

end

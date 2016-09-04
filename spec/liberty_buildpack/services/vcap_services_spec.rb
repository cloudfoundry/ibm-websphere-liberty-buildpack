# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'logging_helper'
require 'liberty_buildpack/services/vcap_services'

describe LibertyBuildpack::Services::VcapServices do
  include_context 'logging_helper'

  shared_context 'service context' do
    let(:service) do
      { 'name' => 'test-name', 'label' => label, 'tags' => ['test-tag'], 'plan' => 'test-plan',
        'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' } }
    end
    let(:same_service) do
      { 'name' => 'diff-name', 'label' => label, 'tags' => ['test-tag'], 'plan' => 'test-plan',
        'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' } }
    end

    let(:services) { described_class.new('test' => [service]) }
    let(:multi_services) { described_class.new('test' => [service], 'test2' => [same_service]) }
    let(:multiple_match_error) { 'Multiple inexact matches exist' }
  end

  shared_examples_for 'a default service with a label value:' do |label_value|
    include_context 'service context' do
      let(:label) { label_value }
    end

    it 'raise error from one_service? if there is more than one of the same service' do
      expect { multi_services.one_service? 'test-tag' }.to raise_error(RuntimeError, /#{multiple_match_error}/)
      expect { multi_services.one_service?(/test-tag/) }.to raise_error(RuntimeError, /#{multiple_match_error}/)
    end

    it 'raise error from one_service? if there is no service that matches' do
      expect(services.one_service?('bad-test')).not_to be
      expect(services.one_service?(/bad-test/)).not_to be
    end

    it 'returns true from one_service? if there is a matching tag' do
      expect(services.one_service?('test-tag')).to be
      expect(services.one_service?(/test-tag/)).to be
    end

    it 'returns false from one_service? if there is a matching service without required credentials' do
      expect(services.one_service?('test-tag', 'bad-credential')).not_to be
      expect(services.one_service?(/test-tag/, 'bad-credential')).not_to be
    end

    it 'returns true from one_service? if there is a matching service with required credentials' do
      expect(services.one_service?('test-tag', 'uri')).to be
      expect(services.one_service?(/test-tag/, 'uri')).to be
    end

    it 'returns true from one_service? if there is a matching service with one required group credentials' do
      expect(services.one_service?('test-tag', %w(uri other))).to be
      expect(services.one_service?(/test-tag/, %w(uri other))).to be
    end

    it 'returns true from one_service? if there is a matching service with two required group credentials' do
      expect(services.one_service?('test-tag', %w(h1 h2))).to be
      expect(services.one_service?(/test-tag/, %w(h1 h2))).to be
    end

    it 'returns false from one_service? if there is a matching service with no required group credentials' do
      expect(services.one_service?('test-tag', %w(foo bar))).not_to be
      expect(services.one_service?(/test-tag/, %w(foo bar))).not_to be
    end

    it 'returns nil from find_service? if there is no service that matches' do
      expect(services.find_service('bad-test')).to be_nil
      expect(services.find_service(/bad-test/)).to be_nil
    end

    it 'returns service from find_service? if there is a matching tag' do
      expect(services.find_service('test-tag')).to be(service)
      expect(services.find_service(/test-tag/)).to be(service)
    end
  end # end of shared example

  describe 'a default service provided by the platform' do
    it_behaves_like 'a default service with a label value:', 'test-label'

    describe 'match service based on label' do
      include_context 'service context' do
        let(:label) { 'test-label' }
      end

      it 'returns service from find_service? if there is a matching label' do
        expect(services.find_service('test-label')).to be(service)
        expect(services.find_service(/test-label/)).to be(service)
      end

      it 'returns service from find_service? if there is a matching name' do
        expect(services.find_service('test-name')).to be_nil
        expect(services.find_service(/test-name/)).to be_nil
      end

      it 'returns true from one_service? if there is a matching label' do
        expect(services.one_service?('test-label')).to be
        expect(services.one_service?(/test-label/)).to be
      end

      it 'returns true from one_service? if there is a matching name' do
        expect(services.one_service?('test-name')).not_to be
        expect(services.one_service?(/test-name/)).not_to be
      end
    end
  end

  describe 'a service provided by the user cannot be matched to a label' do
    it_behaves_like 'a default service with a label value:', 'user-provided'

    describe 'match service based on name' do
      include_context 'service context' do
        let(:label) { 'user-provided' }
      end

      it 'returns true from one_service? if there is a matching name' do
        expect(services.one_service?('test-name')).to be
        expect(services.one_service?(/test-name/)).to be
      end

      it 'returns service from find_service? if there is a matching name' do
        expect(services.find_service('test-name')).to be(service)
        expect(services.find_service(/test-name/)).to be(service)
      end
    end
  end

end

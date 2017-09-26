# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
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

require 'logging_helper'
require 'spec_helper'
require 'liberty_buildpack/repository/version_resolver'
require 'liberty_buildpack/util/tokenized_version'

describe LibertyBuildpack::Repository::VersionResolver do
  include_context 'logging_helper'

  let(:versions) { %w(1.6.0_26 1.6.0_27 1.6.1_14 1.7.0_sr4fp7 1.7.0_sr4fp11 1.8.0_M-7 1.8.0_05 2.0.0 2.0.0a) }

  it 'resolves the default version if no candidate is supplied' do
    expect(described_class.resolve(nil, versions)).to eq(tokenized_version('2.0.0'))
  end

  it 'resolves a wildcard major version' do
    expect(described_class.resolve(tokenized_version('+'), versions)).to eq(tokenized_version('2.0.0'))
  end

  it 'resolves a wildcard minor version' do
    expect(described_class.resolve(tokenized_version('1.+'), versions)).to eq(tokenized_version('1.8.0_05'))
  end

  it 'resolves a wildcard micro version' do
    expect(described_class.resolve(tokenized_version('1.6.+'), versions)).to eq(tokenized_version('1.6.1_14'))
  end

  it 'resolves a wildcard qualifier' do
    expect(described_class.resolve(tokenized_version('1.6.0_+'), versions)).to eq(tokenized_version('1.6.0_27'))
    expect(described_class.resolve(tokenized_version('1.8.0_+'), versions)).to eq(tokenized_version('1.8.0_05'))
    expect(described_class.resolve(tokenized_version('1.7.0_+'), versions)).to eq(tokenized_version('1.7.0_sr4fp11'))
  end

  it 'resolves a non-wildcard version' do
    expect(described_class.resolve(tokenized_version('1.6.0_26'), versions)).to eq(tokenized_version('1.6.0_26'))
    expect(described_class.resolve(tokenized_version('2.0.0'), versions)).to eq(tokenized_version('2.0.0'))
  end

  it 'resolves a non-digit qualifier' do
    expect(described_class.resolve(tokenized_version('1.8.0_M-7'), versions)).to eq(tokenized_version('1.8.0_M-7'))
  end

  it 'raises an exception if no version can be resolved' do
    expect(described_class.resolve(tokenized_version('2.1.0'), versions)).to be_nil
  end

  it 'ignores illegal versions' do
    expect(described_class.resolve(tokenized_version('2.0.+'), versions)).to eq(tokenized_version('2.0.0'))
  end

  it 'returns the most recent version' do
    expect(described_class.version_compare(tokenized_version('1.7.0_sr4fp7'), tokenized_version('1.7.0_sr4fp11'))).to eq(-1)
  end

  it 'eliminates the letters in version numbers' do
    expect(described_class.clean_version_letters('0_sr4fp11')).to eq(%w(0 4 11))
  end

  it 'ignores leading 0s when comparing' do
    expect(described_class.version_compare(tokenized_version('19.0.01'), tokenized_version('19.0.1'))).to eq(-1)
  end

  it 'replaces the suffix "ifx" with a ".5" for easier comparison' do
    expect(described_class.clean_version_letters('0_sr4fp11ifx')).to eq(%w(0 4 11.5))
  end

  def tokenized_version(s)
    LibertyBuildpack::Util::TokenizedVersion.new(s)
  end

end

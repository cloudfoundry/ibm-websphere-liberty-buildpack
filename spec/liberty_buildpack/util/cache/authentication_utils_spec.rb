# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2015 the original author or authors.
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
require 'liberty_buildpack/util/configuration_utils'
require 'liberty_buildpack/util/cache/authentication_utils'

describe LibertyBuildpack::Util::Cache::AuthenticationUtils do

  before(:each) do
    # reset cached value before each test
    described_class.class_variable_set :@@auth_config, nil
  end

  after(:each) do
    # reset cached value after each test
    described_class.class_variable_set :@@auth_config, nil
  end

  it 'should handle empty configuration file' do
    allow(LibertyBuildpack::Util::ConfigurationUtils).to receive(:load)
      .with('auth', true, false).and_return({})
    expect(described_class.send(:authorization_value, 'http://auth.com')).to be_nil
  end

  it 'should return the best match' do
    allow(LibertyBuildpack::Util::ConfigurationUtils).to receive(:load)
      .with('auth', true, false).and_return('http://auth.com' => 'Basic One', 'http://auth.com/file/' => 'Basic Two')
    expect(described_class.send(:authorization_value, 'http://auth.com/file/file.zip')).to eq 'Basic Two'
    expect(described_class.send(:authorization_value, 'http://auth.com/dir/file.zip')).to eq 'Basic One'
    expect(described_class.send(:authorization_value, 'http://auth2.com/dir/file.zip')).to be_nil
  end

  it 'should handle authorization specified as a string' do
    allow(LibertyBuildpack::Util::ConfigurationUtils).to receive(:load)
      .with('auth', true, false).and_return('http://auth.com' => 'Bearer Secret')

    request = Net::HTTP::Get.new('/')
    expect(described_class.authorization(request, 'http://auth.com')).to eq true
    expect(request['Authorization']).to eq 'Bearer Secret'
  end

  it 'should handle authorization specified as a map' do
    allow(LibertyBuildpack::Util::ConfigurationUtils).to receive(:load)
      .with('auth', true, false).and_return('http://auth.com' => { 'username' => 'test', 'password' => 'test' })

    request = Net::HTTP::Get.new('/')
    expect(described_class.authorization(request, 'http://auth.com')).to eq true
    # Value dGVzdDp0ZXN0 is 'test:test' in base64
    expect(request['Authorization']).to eq 'Basic dGVzdDp0ZXN0'
  end

  it 'should not match if "username" key is missing' do
    allow(LibertyBuildpack::Util::ConfigurationUtils).to receive(:load)
      .with('auth', true, false).and_return('http://auth.com' => { 'password' => 'test' })

    request = Net::HTTP::Get.new('/')
    expect(described_class.authorization(request, 'http://auth.com')).to eq false
  end

  it 'should not match if "password" key is missing' do
    allow(LibertyBuildpack::Util::ConfigurationUtils).to receive(:load)
      .with('auth', true, false).and_return('http://auth.com' => { 'username' => 'test' })

    request = Net::HTTP::Get.new('/')
    expect(described_class.authorization(request, 'http://auth.com')).to eq false
  end

  it 'should not update Authorization header if it is present' do
    allow(LibertyBuildpack::Util::ConfigurationUtils).to receive(:load)
      .with('auth', true, false).and_return('http://auth.com' => 'Basic One')

    request = Net::HTTP::Get.new('/')
    request['Authorization'] = 'Basic Two'
    expect(described_class.authorization(request, 'http://auth.com')).to eq false
    expect(request['Authorization']).to eq 'Basic Two'
  end

end

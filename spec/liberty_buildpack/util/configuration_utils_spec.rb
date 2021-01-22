# frozen_string_literal: true

# IBM WebSphere Application Server Liberty Buildpack
# Copyright IBM Corp. 2015, 2016
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

require 'liberty_buildpack/util'
require 'liberty_buildpack/util/configuration_utils'
require 'fileutils'
require 'logging_helper'
require 'pathname'
require 'spec_helper'
require 'yaml'

describe LibertyBuildpack::Util::ConfigurationUtils do
  include_context 'logging_helper'

  let(:test_data) do
    { 'foo' => { 'one' => '1', 'two' => 2 },
      'bar' => { 'alpha' => { 'one' => 'cat', 'two' => 'dog' } },
      'version' => '1.7.1',
      'not_here' => nil }
  end

  it 'not load absent configuration file' do
    pathname = instance_double(Pathname)
    allow(Pathname).to receive(:new).and_return(pathname)
    allow(pathname).to receive(:exist?).and_return(false)

    expect(described_class.load('test')).to eq({})
  end

  context do

    before do
      pathname = instance_double(Pathname)
      allow(Pathname).to receive(:new).and_return(pathname)
      allow(pathname).to receive(:exist?).and_return(true)

      allow(YAML).to receive(:load_file).and_return(test_data)
    end

    it 'load configuration file' do
      expect(described_class.load('test', false)).to eq(test_data)
    end

    it 'load configuration file and clean nil values' do
      expect(described_class.load('test', true)).to eq('foo' => { 'one' => '1', 'two' => 2 },
                                                       'bar' => { 'alpha' => { 'one' => 'cat', 'two' => 'dog' } },
                                                       'version' => '1.7.1')
    end

    context do

      let(:environment) do
        { 'JBP_CONFIG_TEST' => '{bar: {alpha: {one: 3, two: {one: 3}}, bravo: newValue}, foo: lion}' }
      end

      it 'overlays matching environment variables' do

        expect(described_class.load('test')).to eq('foo' => { 'one' => '1', 'two' => 2 },
                                                   'bar' => { 'alpha' => { 'one' => 3, 'two' => 'dog' } },
                                                   'version' => '1.7.1')
      end

    end

    context do

      let(:environment) do
        { 'JBP_CONFIG_TEST' => '{version: 1.8.+}' }
      end

      it 'overlays simple matching environment variable' do
        expect(described_class.load('test')).to eq('foo' => { 'one' => '1', 'two' => 2 },
                                                   'bar' => { 'alpha' => { 'one' => 'cat', 'two' => 'dog' } },
                                                   'version' => '1.8.+')
      end

    end

    context do

      let(:environment) do
        { 'JBP_CONFIG_TEST' => 'Not an array or a hash' }
      end

      it 'raises an exception when invalid override value is specified' do
        expect { described_class.load('test') }
          .to raise_error(/User configuration value in environment variable JBP_CONFIG_TEST is not valid/)
      end

    end

    context do

      let(:environment) do
        { 'JBP_CONFIG_TEST' => '{version:1.8.+}' }
      end

      it 'diagnoses invalid YAML syntax' do
        expect { described_class.load('test') }
          .to raise_error(/User configuration value in environment variable JBP_CONFIG_TEST has invalid syntax/)
      end

    end

  end

  private

  def file_contents(file)
    header = []
    File.open(file, 'r') do |f|
      f.each do |line|
        break if line =~ /^---/

        header << line
      end
    end
    header
  end

end

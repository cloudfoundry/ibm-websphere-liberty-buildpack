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
require 'liberty_buildpack/framework/java_opts'

module LibertyBuildpack::Framework

  describe JavaOpts do

    let(:java_opts) { [] }

    it 'should detect with java.opts configuration' do
      detected = JavaOpts.new(
        java_opts: java_opts,
        app_dir: 'root',
        configuration: { 'java_opts' => '-Xmx1024M' }
      ).detect

      expect(detected).to eq('java-opts')
    end

    it 'should detect with java_opts ENV and configuration' do
      detected = JavaOpts.new(
        java_opts: java_opts,
        app_dir: 'root',
        configuration: { 'java_opts' => '-Xmx1024M' },
        environment: { 'JAVA_OPTS' => '-Xms1024M' }
      ).detect

      expect(detected).to eq('java-opts')
    end

    it 'should not detect with nil java_opts configuration' do
      detected = JavaOpts.new(
        java_opts: java_opts,
        app_dir: 'root',
        configuration: { 'java_opts' => nil }
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect without java_opts configuration' do
      detected = JavaOpts.new(
        java_opts: java_opts,
        app_dir: 'root',
        configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect with ENV and without java_opts configuration' do
      detected = JavaOpts.new(
        java_opts: java_opts,
        app_dir: 'root',
        configuration: {},
        environment: { 'JAVA_OPTS' => '-Xms1024M' }
      ).detect

      expect(detected).to be_nil
    end

    it 'should add split java_opts to context' do
      JavaOpts.new(
        java_opts: java_opts,
        app_dir: 'root',
        configuration: { 'java_opts' => "-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,server=y,address=8000,suspend=y -XX:OnOutOfMemoryError='kill -9 %p'" }
      ).release

      expect(java_opts).to include('-Xdebug')
      expect(java_opts).to include('-Xnoagent')
      expect(java_opts).to include('-Xrunjdwp:transport=dt_socket,server=y,address=8000,suspend=y')
      expect(java_opts).to include('-XX:OnOutOfMemoryError=kill\ -9\ %p')
    end

    it 'should include ENV options if configuration contains from_environment key' do
      JavaOpts.new(
        java_opts: java_opts,
        app_dir: 'root',
        configuration: { 'from_environment' => true },
        environment: { 'JAVA_OPTS' => '-Xms1024M' }
      ).release

      expect(java_opts).to include('-Xms1024M')
    end

    it 'should not include ENV options if configuration does not contain form_environment key' do
      JavaOpts.new(
        java_opts: java_opts,
        app_dir: 'root',
        configuration: {},
        environment: { 'JAVA_OPTS' => '-Xms1024M' }
      ).release

      expect(java_opts).not_to include('-Xms1024M')
    end

    it 'should raise an error if a memory region is configured using openjdk' do
      expect { JavaOpts.new(java_opts: java_opts, configuration: { 'java_opts' => '-Xms1024M', app_dir: 'root' }, jvm_type: 'openjdk').compile }.to raise_error(/-Xms/)
      expect { JavaOpts.new(java_opts: java_opts, configuration: { 'java_opts' => '-Xmx1024M', app_dir: 'root' }, jvm_type: 'openjdk').compile }.to raise_error(/-Xmx/)
      expect { JavaOpts.new(java_opts: java_opts, configuration: { 'java_opts' => '-XX:MaxMetaspaceSize=128M', app_dir: 'root' }, jvm_type: 'openjdk').compile }.to raise_error(/-XX:MaxMetaspaceSize/)
      expect { JavaOpts.new(java_opts: java_opts, configuration: { 'java_opts' => '-XX:MaxPermSize=128M', app_dir: 'root' }, jvm_type: 'openjdk').compile }.to raise_error(/-XX:MaxPermSize/)
      expect { JavaOpts.new(java_opts: java_opts, configuration: { 'java_opts' => '-Xss1M', app_dir: 'root' }, jvm_type: 'openjdk').compile }.to raise_error(/-Xss/)
    end

  end

end

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
require 'component_helper'
require 'fileutils'
require 'liberty_buildpack/jre/openj9'

module LibertyBuildpack::Jre

  describe OpenJ9 do
    include_context 'component_helper'

    let(:default_configuration) do
      { 'version' => '11.+',
        'type' => 'jre',
        'heap_size' => 'normal' }
    end

    let(:application_cache) { double('ApplicationCache') }

    def stubs
      LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with('https://api.adoptopenjdk.net/v2/info/releases/openjdk11?openjdk_impl=openj9&type=jre&arch=x64&os=linux&heap_size=normal').and_yield(File.open('spec/fixtures/openj9-releases.json'))
      application_cache.stub(:get).with('https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11%2B28/OpenJDK11-jre_x64_linux_openj9_11_28.tar.gz').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))
    end

    def openj9(root, configuration = default_configuration)
      stubs
      component = OpenJ9.new(
        app_dir: root,
        java_home: '',
        java_opts: [],
        configuration: configuration,
        jvm_type: 'openj9'
      )
      component
    end

    it 'adds the JAVA_HOME to java_home' do
      Dir.mktmpdir do |root|
        java_home = ''

        OpenJ9.new(
          app_dir: root,
          java_home: java_home,
          java_opts: [],
          configuration: default_configuration
        )

        expect(java_home).to eq('.java')
      end
    end

    describe 'detect' do

      it 'should detect with id of openj9-<version>' do
        Dir.mktmpdir do |root|
          detected = openj9(root).detect

          expect(detected).to eq('openj9-jdk-11+28')
        end
      end

    end

    describe 'compile' do

      it 'should extract Java from a tar gz' do
        Dir.mktmpdir do |root|
          openj9(root).compile

          java = File.join(root, '.java', 'bin', 'java')
          expect(File.exist?(java)).to eq(true)
        end
      end

      it 'places the killjava script (with appropriately substituted content) in the diagnostics directory' do
        Dir.mktmpdir do |root|
          openj9(root).compile

          expect(Pathname.new(File.join(LibertyBuildpack::Diagnostics.get_diagnostic_directory(root), OpenJ9::KILLJAVA_FILE_NAME))).to exist
        end
      end

      it 'should add 0.50 ratio when heap_size_ratio is set to 50%' do
        Dir.mktmpdir do |root|
          configuration = default_configuration.clone
          configuration['heap_size_ratio'] = '0.50'
          openj9(root, configuration).compile

          memory_config = File.read("#{root}/.memory_config/heap_size_ratio_config")
          expect(memory_config).to include('0.5')
        end
      end

      it 'should add 0.75 ratio when heap_size_ratio is not set' do
        Dir.mktmpdir do |root|
          openj9(root).compile

          memory_config = File.read("#{root}/.memory_config/heap_size_ratio_config")
          expect(memory_config).to include('0.75')
        end
      end

    end # end of compile shared tests

    describe 'release' do

      subject(:released) do
        Dir.mktmpdir do |root|
          component = openj9(root)
          component.detect
          component.release
        end
      end

      it 'should add default dump options that output data to the common dumps directory, if enabled' do
        expect(released).to include('-Xdump:none',
                                    '-Xshareclasses:none',
                                    '-Xdump:heap:defaults:file=./../dumps/heapdump.%Y%m%d.%H%M%S.%pid.%seq.phd',
                                    '-Xdump:java:defaults:file=./../dumps/javacore.%Y%m%d.%H%M%S.%pid.%seq.txt',
                                    '-Xdump:snap:defaults:file=./../dumps/Snap.%Y%m%d.%H%M%S.%pid.%seq.trc',
                                    '-Xdump:heap+java+snap:events=user')
      end

      it 'should provide troubleshooting info for JVM shutdowns' do
        expect(released).to include("-Xdump:tool:events=systhrow,filter=java/lang/OutOfMemoryError,request=serial+exclusive,exec=./#{LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{OpenJ9::KILLJAVA_FILE_NAME}")
      end
    end

  end
end

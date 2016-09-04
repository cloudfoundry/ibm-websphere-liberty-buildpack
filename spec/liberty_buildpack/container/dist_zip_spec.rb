# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require 'component_helper'
require 'liberty_buildpack/container/dist_zip'
require 'liberty_buildpack/container/liberty'

module LibertyBuildpack::Container
  describe DistZip do
    include_context 'component_helper'

    describe 'detect', configuration: {} do
      it 'does not detect a non-distZip application' do
        detected = DistZip.new(
          app_dir: 'spec/fixtures/container_main_with_web_inf',
          configuration: {},
          java_home: '',
          java_opts: [],
          license_ids: {}
        ).detect

        expect(detected).to be_nil
      end

      it 'detects a distZip application' do
        detected = DistZip.new(
          app_dir: 'spec/fixtures/container_dist_zip',
          configuration: {},
          java_home: '',
          java_opts: [],
          license_ids: {}
        ).detect

        expect(detected).to eq('dist-zip')
      end
    end

    describe 'compile',
             configuration: {} do

      it 'Should make sure the classpath gets updated correctly' do
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p File.join(root, 'bin')
          FileUtils.mkdir_p File.join(root, 'lib')
          File.open(File.join(root, 'lib', 'foobar.jar'), 'w')
          File.open(File.join(root, 'bin', 'application'), 'w') do |file|
            file.write('CLASSPATH=$APP_HOME/lib')
          end

          DistZip.new(
            app_dir: root,
            lib_directory: File.join(root, 'lib'),
            configuration: {},
            java_home: '.java',
            java_opts: [],
            license_ids: {}
          ).compile

          data = File.read(File.open(File.join(root, 'bin', 'application')))
          expect(data).to include('$APP_HOME/lib/foobar.jar')
        end
      end

      it 'Should make sure the App classpath gets updated correctly' do
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p File.join(root, 'bin')
          FileUtils.mkdir_p File.join(root, 'lib')
          File.open(File.join(root, 'lib', 'appfoo.jar'), 'w')
          File.open(File.join(root, 'bin', 'application'), 'w') do |file|
            file.write('declare -r app_classpath="$app_home/lib"')
          end

          DistZip.new(
            app_dir: root,
            lib_directory: File.join(root, 'lib'),
            configuration: {},
            java_home: '.java',
            java_opts: [],
            license_ids: {}
          ).compile

          data = File.read(File.open(File.join(root, 'bin', 'application')))
          expect(data).to include('$app_home/lib/appfoo.jar')
        end
      end
    end

    describe 'release',
             configuration: {} do

      it 'should include command line argument java_opts' do
        released = DistZip.new(
          app_dir: 'spec/fixtures/container_dist_zip',
          configuration: {},
          java_home: '.java',
          java_opts: %w(foo bar),
          license_ids: {}
        ).release

        expect(released).to include('JAVA_OPTS="foo bar"')
      end

      it 'should include the application path' do
        released = DistZip.new(
          app_dir: 'spec/fixtures/container_dist_zip',
          configuration: {},
          java_home: '.java',
          java_opts: [],
          license_ids: {}
        ).release

        expect(released).to include('$PWD/bin/application')
      end
    end
  end
end

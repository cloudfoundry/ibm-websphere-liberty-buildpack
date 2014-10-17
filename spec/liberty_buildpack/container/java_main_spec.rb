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

require 'spec_helper'
require 'liberty_buildpack/container/java_main'
require 'liberty_buildpack/container/container_utils'

module LibertyBuildpack::Container

  describe JavaMain do

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    describe 'detect' do
      it 'should detect main class in manifest' do
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p File.join(root, 'META-INF')
          File.open(File.join(root, 'META-INF', 'MANIFEST.MF'), 'w') do |file|
            file.write('Main-Class: detect.test')
          end

          detected = JavaMain.new(
            app_dir: root,
            configuration: {}
          ).detect

          expect(detected).to eq(%w(JAR java-main))
        end
      end

      it 'should detect main class in configuration' do
        Dir.mktmpdir do |root|
          detected = JavaMain.new(
            app_dir: root,
            configuration: { 'java_main_class' => 'java-main' }
          ).detect

          expect(detected).to eq(%w(JAR java-main))
        end
      end

      it 'should not detect without manifest' do
        Dir.mktmpdir do |root|

          detected = JavaMain.new(
           app_dir: root,
           configuration: {}
          ).detect

          expect(detected).to be_nil
        end
      end

      it 'should update the common_paths provided by the buildpack to include the Standalone Java container path' do
        Dir.mktmpdir do |root|

          java_main = JavaMain.new(
           app_dir: root,
           common_paths: CommonPaths.new,
           configuration: { 'java_main_class' => 'java-main' }
          )
          java_main.detect

          actual_common_paths = java_main.instance_variable_get(:@common_paths)
          expect(actual_common_paths.instance_variable_get(:@relative_location)).to eq('../')
        end
      end

      it 'should result with Java Standalone path when the common_paths is not provided in its context' do
        Dir.mktmpdir do |root|

          java_main = JavaMain.new(
           app_dir: root,
           configuration: { 'java_main_class' => 'java-main' }
          )
          java_main.detect

          actual_common_paths = java_main.instance_variable_get(:@common_paths)
          expect(actual_common_paths.instance_variable_get(:@relative_location)).to eq('../')
        end
      end
    end

    describe 'compile' do
      it 'should find and copy .java-overlay included in JAR file during push' do
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p File.join(root, '.java')
          FileUtils.mkdir_p File.join(root, 'resources', '.java-overlay', '.java')
          File.open(File.join(root, 'resources', '.java-overlay', '.java', 'overlay.txt'), 'w') do |file|
            file.write('overlay file')
          end
          File.open(File.join(root, '.java', 'test.txt'), 'w') do |file|
            file.write('test file that should still exist after overlay')
          end

          JavaMain.new(
          app_dir: root,
          java_home: '.java',
          java_opts: [],
          configuration: { 'java_main_class' => 'com.ibm.rspec.test' }
          ).compile

          expect(File.exists?(File.join root, '.java', 'overlay.txt')).to eq(true)
          expect(File.exists?(File.join root, '.java', 'test.txt')).to eq(true)
        end
      end
    end

    describe 'release' do
      context 'default jre' do
        before do
          allow(File).to receive(:exists?).with(%r{.java/jre/bin/java}).and_return(true)
          allow(File).to receive(:exists?).with(%r{.java/bin/java}).and_return(true)
        end

        it 'should return the java command' do
          Dir.mktmpdir do |root|
            released = JavaMain.new(
            app_dir: root,
            java_home: '.java',
            java_opts: [],
            configuration: { 'java_main_class' => 'com.ibm.rspec.test' }
            ).release

            expect(released).to include('$PWD/.java/jre/bin/java')
          end
        end

        it 'should return classpath entries when Class-Path is specified.' do
          Dir.mktmpdir do |root|
            FileUtils.mkdir_p File.join(root, 'META-INF')
            File.open(File.join(root, 'META-INF', 'MANIFEST.MF'), 'w') do |file|
              file.write('Class-Path: additional_libs/test-jar-1.jar test-jar-2.jar')
            end

            detected = JavaMain.new(
              app_dir: root,
              java_home: '.java',
              java_opts: [],
              configuration: {}
            ).release

            expect(detected).to include('-cp $PWD/additional_libs/test-jar-1.jar:$PWD/test-jar-2.jar')
          end
        end

        it 'should return command line arguments when they are specified' do
          Dir.mktmpdir do |root|

            detected = JavaMain.new(
              app_dir: root,
              java_home: '.java',
              java_opts: [],
              configuration: { 'java_main_class' => 'com.ibm.rspec.test', 'arguments' => 'some arguments' }
            ).release

            expect(detected).to include('com.ibm.rspec.test some arguments')
          end
        end

        it 'should return spring boot applications with a JarLauncher in manifest' do
          Dir.mktmpdir do |root|
            FileUtils.mkdir_p File.join(root, 'META-INF')
            File.open(File.join(root, 'META-INF', 'MANIFEST.MF'), 'w') do |file|
              file.write('Main-Class: org.springframework.boot.loader.JarLauncher')
            end

            detected = JavaMain.new(
              app_dir: root,
              java_home: '.java',
              java_opts: [],
              configuration: {}
            ).release

            expect(detected).to include('org.springframework.boot.loader.JarLauncher --server.port=$PORT')
          end
        end

        it 'should return spring boot applications with a WarLauncher in manifest' do
          Dir.mktmpdir do |root|
            FileUtils.mkdir_p File.join(root, 'META-INF')
            File.open(File.join(root, 'META-INF', 'MANIFEST.MF'), 'w') do |file|
              file.write('Main-Class: org.springframework.boot.loader.WarLauncher')
            end

            detected = JavaMain.new(
              app_dir: root,
              java_home: '.java',
              java_opts: [],
              configuration: {}
            ).release

            expect(detected).to include('org.springframework.boot.loader.WarLauncher --server.port=$PORT')
          end
        end

        it 'should return spring boot applications with a PropertiesLauncher in manifest' do
          Dir.mktmpdir do |root|
            FileUtils.mkdir_p File.join(root, 'META-INF')
            File.open(File.join(root, 'META-INF', 'MANIFEST.MF'), 'w') do |file|
              file.write('Main-Class: org.springframework.boot.loader.PropertiesLauncher')
            end

            detected = JavaMain.new(
              app_dir: root,
              java_home: '.java',
              java_opts: [],
              configuration: {}
            ).release

            expect(detected).to include('org.springframework.boot.loader.PropertiesLauncher --server.port=$PORT')
          end
        end

        it 'should return spring boot applications with a JarLauncher in configuration' do
          Dir.mktmpdir do |root|

            detected = JavaMain.new(
              app_dir: root,
              java_home: '.java',
              java_opts: [],
              configuration: { 'java_main_class' => 'org.springframework.boot.loader.JarLauncher' }
            ).release

            expect(detected).to include('org.springframework.boot.loader.JarLauncher --server.port=$PORT')
          end
        end

        it 'should return spring boot applications with a WarLauncher in configuration' do
          Dir.mktmpdir do |root|

            detected = JavaMain.new(
              app_dir: root,
              java_home: '.java',
              java_opts: [],
              configuration: { 'java_main_class' => 'org.springframework.boot.loader.WarLauncher' }
            ).release

            expect(detected).to include('org.springframework.boot.loader.WarLauncher --server.port=$PORT')
          end
        end

        it 'should return spring boot applications with a PropertiesLauncher in configuration' do
          Dir.mktmpdir do |root|

            detected = JavaMain.new(
              app_dir: root,
              java_home: '.java',
              java_opts: [],
              configuration: { 'java_main_class' => 'org.springframework.boot.loader.PropertiesLauncher' }
            ).release

            expect(detected).to include('org.springframework.boot.loader.PropertiesLauncher --server.port=$PORT')
          end
        end
      end # end of default jre context

      context 'non jre' do
        it 'should return the java command adjusted for a nondefault java bin location' do
          allow(File).to receive(:exists?).with(%r{.java/jre/bin/java}).and_return(false)
          allow(File).to receive(:exists?).with(%r{.java/bin/java}).and_return(true)

          Dir.mktmpdir do |root|
            released = JavaMain.new(
            app_dir: root,
            java_home: '.java',
            java_opts: [],
            configuration: { 'java_main_class' => 'com.ibm.rspec.test' }
            ).release

            expect(released).to include('$PWD/.java/bin/java')
          end
        end
      end

    end # end of release describe

  end

end

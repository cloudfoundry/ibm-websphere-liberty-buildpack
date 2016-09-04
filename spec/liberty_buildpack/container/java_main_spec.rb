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
require 'component_helper'
require 'liberty_buildpack/container/java_main'
require 'liberty_buildpack/container/container_utils'

module LibertyBuildpack::Container

  describe JavaMain do
    include_context 'component_helper'

    before do |example|
      $stdout = StringIO.new
      $stderr = StringIO.new

      # JavaMain tests can specify what needs to be written to the META-INF/MANIFEST.MF
      java_main_manifest = example.metadata[:java_main_manifest]
      if java_main_manifest
        FileUtils.mkdir_p File.join(app_dir, 'META-INF')
        File.open(File.join(app_dir, 'META-INF', 'MANIFEST.MF'), 'w') do |file|
          file.write(java_main_manifest)
        end
      end
    end

    describe 'detect', configuration: {} do

      subject(:detected) do |example|
        JavaMain.new(context).detect
      end

      it 'should detect main class in manifest',
         java_main_manifest: 'Main-Class: detect.test' do

        expect(detected).to eq(%w(JAR java-main))
      end

      it 'should detect main class in configuration',
         configuration: { 'java_main_class' => 'java-main' } do

        expect(detected).to eq(%w(JAR java-main))
      end

      it 'should not detect without manifest' do
        expect(detected).to be_nil
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

          expect(File.exist?(File.join(root, '.java', 'overlay.txt'))).to eq(true)
          expect(File.exist?(File.join(root, '.java', 'test.txt'))).to eq(true)
          expect(Dir.exist?(File.join(root, 'resources', '.java-overlay'))).to eq(false)
        end
      end
    end

    describe 'release',
             java_home: '.java',
             java_opts: [],
             configuration: {} do

      subject(:released) { JavaMain.new(context).release }

      it 'should include command line argument JVM_ARGS',
         configuration: { 'java_main_class' => 'com.ibm.rspec.test' } do

        expect(released).to include('java $JVM_ARGS com.ibm.rspec.test')
      end

      it 'should include command line argument JVM_ARGS after JAVA_OPTS values',
         java_opts: %w(user_java_opts1 user_java_opts2),
         configuration: { 'java_main_class' => 'com.ibm.rspec.test' } do

        expect(released).to include('java user_java_opts1 user_java_opts2 $JVM_ARGS com.ibm.rspec.test')
      end

      it 'should return command line arguments when they are specified',
         configuration: {
           'java_main_class' => 'com.ibm.rspec.test',
           'arguments' => 'some arguments'
         } do

        expect(released).to include('com.ibm.rspec.test some arguments')
      end

      it 'should return classpath entries when Class-Path is specified.',
         java_main_manifest: 'Class-Path: additional_libs/test-jar-1.jar test-jar-2.jar' do

        expect(released).to include('-cp $PWD/additional_libs/test-jar-1.jar:$PWD/test-jar-2.jar')
      end

      it 'should return spring boot applications with a JarLauncher in manifest',
         java_main_manifest: 'Main-Class: org.springframework.boot.loader.JarLauncher' do

        expect(released).to include('org.springframework.boot.loader.JarLauncher --server.port=$PORT')
      end

      it 'should return spring boot applications with a WarLauncher in manifest',
         java_main_manifest: 'Main-Class: org.springframework.boot.loader.WarLauncher' do

        expect(released).to include('org.springframework.boot.loader.WarLauncher --server.port=$PORT')
      end

      it 'should return spring boot applications with a PropertiesLauncher in manifest',
         java_main_manifest: 'Main-Class: org.springframework.boot.loader.PropertiesLauncher' do

        expect(released).to include('org.springframework.boot.loader.PropertiesLauncher --server.port=$PORT')
      end

      it 'should return spring boot applications with a JarLauncher in configuration',
         configuration: { 'java_main_class' => 'org.springframework.boot.loader.JarLauncher' } do

        expect(released).to include('org.springframework.boot.loader.JarLauncher --server.port=$PORT')
      end

      it 'should return spring boot applications with a WarLauncher in configuration',
         configuration: { 'java_main_class' => 'org.springframework.boot.loader.WarLauncher' } do

        expect(released).to include('org.springframework.boot.loader.WarLauncher --server.port=$PORT')
      end

      it 'should return spring boot applications with a PropertiesLauncher in configuration',
         configuration: { 'java_main_class' => 'org.springframework.boot.loader.PropertiesLauncher' } do

        expect(released).to include('org.springframework.boot.loader.PropertiesLauncher --server.port=$PORT')
      end

      context 'default path which has jre in it' do

        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(%r{.java/jre/bin/java}).and_return(true)
          allow(File).to receive(:exist?).with(%r{.java/bin/java}).and_return(false)
        end

        it 'should return the java command',
           configuration: { 'java_main_class' => 'com.ibm.rspec.test' } do

          expect(released).to include('$PWD/.java/jre/bin/java')
        end

      end # end of default jre context

      context 'paths that do not have jre in it' do

        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(%r{.java/jre/bin/java}).and_return(false)
          allow(File).to receive(:exist?).with(%r{.java/bin/java}).and_return(true)
        end

        it 'should return the java command adjusted for a nondefault java bin location',
           configuration: { 'java_main_class' => 'com.ibm.rspec.test' } do

          expect(released).to include('$PWD/.java/bin/java')
        end
      end
    end # end of release describe

  end

end

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
require 'logging_helper'
require 'liberty_buildpack/framework/spring_auto_reconfiguration'

module LibertyBuildpack::Framework

  describe SpringAutoReconfiguration do
    include_context 'logging_helper'

    SPRING_AUTO_RECONFIGURATION_VERSION = LibertyBuildpack::Util::TokenizedVersion.new('0.6.8')

    SPRING_AUTO_RECONFIGURATION_DETAILS = [SPRING_AUTO_RECONFIGURATION_VERSION, 'test-uri'].freeze

    let(:application_cache) { double('ApplicationCache') }
    let(:web_xml_modifier) { double('WebXmlModifier') }

    it 'should detect with Spring JAR in WEB-INF' do
      LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)

      detected = SpringAutoReconfiguration.new(
        app_dir: 'spec/fixtures/framework_auto_reconfiguration_servlet_3',
        configuration: {}
      ).detect

      expect(detected).to eq('spring-auto-reconfiguration-0.6.8')
    end

    it 'should detect with Spring JAR in EAR app' do
      LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)

      detected = SpringAutoReconfiguration.new(
        app_dir: 'spec/fixtures/framework_auto_reconfiguration_servlet_4',
        configuration: {}
      ).detect

      expect(detected).to eq('spring-auto-reconfiguration-0.6.8')
    end

    it 'should not detect without Spring JAR' do
      detected = SpringAutoReconfiguration.new(
        app_dir: 'spec/fixtures/framework_none',
        configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect when disabled' do
      LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)

      detected = SpringAutoReconfiguration.new(
        app_dir: 'spec/fixtures/framework_auto_reconfiguration_servlet_4',
        configuration: { 'enabled' => false }
      ).detect

      expect(detected).to be_nil
    end

    it 'should only create a lib directory if spring_core*.jar exists' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory
        FileUtils.cp_r 'spec/fixtures/framework_auto_reconfiguration_servlet_5/.', root

        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)
        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-auto-reconfiguration.jar'))

        SpringAutoReconfiguration.new(
          app_dir: root,
          lib_directory: lib_directory,
          configuration: {}
        ).compile

        expect(File.exist?(File.join(lib_directory, 'spring-auto-reconfiguration-0.6.8.jar'))).to eq(true)
        expect(File.directory?(File.join(root, 'no_spring_app.war', 'WEB-INF', 'lib'))).to eq(false)
        expect(File.symlink?(File.join(root, 'spring_app.ear', 'lib', 'spring-auto-reconfiguration-0.6.8.jar'))).to eq(true)
        expect(File.symlink?(File.join(root, 'spring_app.war', 'WEB-INF', 'lib', 'spring-auto-reconfiguration-0.6.8.jar'))).to eq(true)
      end
    end

    it 'should copy additional libraries to the lib directory' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory
        FileUtils.cp_r 'spec/fixtures/framework_auto_reconfiguration_servlet_5/.', root

        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)
        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-auto-reconfiguration.jar'))

        SpringAutoReconfiguration.new(
          app_dir: root,
          lib_directory: lib_directory,
          configuration: {}
        ).compile

        expect(File.exist?(File.join(lib_directory, 'spring-auto-reconfiguration-0.6.8.jar'))).to eq(true)
      end
    end

    it 'should update web.xml if it exists' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory
        FileUtils.cp_r 'spec/fixtures/framework_auto_reconfiguration_servlet_2/.', root
        web_xml = File.join root, 'WEB-INF', 'web.xml'

        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)
        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-auto-reconfiguration.jar'))
        LibertyBuildpack::Framework::WebXmlModifier.stub(:new).and_return(web_xml_modifier)
        web_xml_modifier.should_receive(:augment_root_context)
        web_xml_modifier.should_receive(:augment_servlet_contexts)
        web_xml_modifier.stub(:to_s).and_return('Test Content')

        SpringAutoReconfiguration.new(
          app_dir: root,
          lib_directory: lib_directory,
          configuration: {}
        ).compile

        File.open(web_xml) { |file| expect(file.read).to eq('Test Content') }
      end
    end

    it 'should link additional libraries to a zipped server webapp' do
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p File.join(root, 'wlp', 'usr', 'servers', 'myServer')
        File.open(File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'server.xml'), 'w') do |file|
          file.write('your text')
        end
        app_dir = File.join(root, 'wlp', 'usr', 'servers', 'myServer', 'apps')
        FileUtils.mkdir_p(app_dir)
        stub_war_file = File.join('spec', 'fixtures', 'stub-spring.war')
        war_file = File.join(app_dir, 'test.war')
        FileUtils.cp(stub_war_file, war_file)

        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory

        Dir['spec/fixtures/additional_libs/*'].each { |file| FileUtils.cp(file, lib_directory) }

        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)

        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/wlp-stub.jar'))

        LibertyBuildpack::Container::Liberty.new(
          app_dir: root,
          lib_directory: lib_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
        )

        SpringAutoReconfiguration.new(
          app_dir: root,
          lib_directory: lib_directory,
          configuration: {}
        ).compile

        lib = File.join(war_file, 'WEB-INF', 'lib')
        test_jar_1 = File.join lib, 'test-jar-1.jar'
        test_jar_2 = File.join lib, 'test-jar-2.jar'
        test_text = File.join lib, 'test-text.txt'
        expect(File.exist?(test_jar_1)).to eq(true)
        expect(File.symlink?(test_jar_1)).to eq(true)
        expect(File.readlink(test_jar_1)).to eq(Pathname.new(File.join(lib_directory, 'test-jar-1.jar')).relative_path_from(Pathname.new(lib)).to_s)

        expect(File.exist?(test_jar_2)).to eq(true)
        expect(File.symlink?(test_jar_2)).to eq(true)
        expect(File.readlink(test_jar_2)).to eq(Pathname.new(File.join(lib_directory, 'test-jar-2.jar')).relative_path_from(Pathname.new(lib)).to_s)

        expect(File.exist?(test_text)).to eq(false)
      end
    end

    it 'should link additional libraries to a webapp' do
      Dir.mktmpdir do |root|
        app_dir = root
        Dir.mkdir File.join(app_dir, 'WEB-INF')
        Dir.mkdir File.join(app_dir, 'WEB-INF', 'lib')
        File.new(File.join(app_dir, 'WEB-INF', 'lib', 'spring-core.jar'), 'w')

        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory

        Dir['spec/fixtures/additional_libs/*'].each { |file| FileUtils.cp(file, lib_directory) }

        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)
        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/wlp-stub.jar'))

        LibertyBuildpack::Container::Liberty.new(
          app_dir: root,
          lib_directory: lib_directory,
          configuration: {},
          environment: {},
          license_ids: { 'IBM_LIBERTY_LICENSE' => '1234-ABCD' }
        )

        SpringAutoReconfiguration.new(
          app_dir: root,
          lib_directory: lib_directory,
          configuration: {}
        ).compile

        lib = File.join(app_dir, 'WEB-INF', 'lib')
        test_jar_1 = File.join lib, 'test-jar-1.jar'
        test_jar_2 = File.join lib, 'test-jar-2.jar'
        test_text = File.join lib, 'test-text.txt'

        expect(File.exist?(test_jar_1)).to eq(true)
        expect(File.symlink?(test_jar_1)).to eq(true)
        expect(File.readlink(test_jar_1)).to eq(Pathname.new(File.join(lib_directory, 'test-jar-1.jar')).relative_path_from(Pathname.new(lib)).to_s)

        expect(File.exist?(test_jar_2)).to eq(true)
        expect(File.symlink?(test_jar_2)).to eq(true)
        expect(File.readlink(test_jar_2)).to eq(Pathname.new(File.join(lib_directory, 'test-jar-2.jar')).relative_path_from(Pathname.new(lib)).to_s)

        expect(File.exist?(test_text)).to eq(false)
      end
    end

  end

end

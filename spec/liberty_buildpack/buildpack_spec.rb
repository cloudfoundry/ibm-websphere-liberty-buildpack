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

require 'application_helper'
require 'logging_helper'
require 'spec_helper'
require 'liberty_buildpack/buildpack'
require 'liberty_buildpack/diagnostics/logger_factory'

module LibertyBuildpack

  APP_DIR = 'test-app-dir'.freeze

  describe Buildpack do
    include_context 'application_helper'
    include_context 'logging_helper'

    let(:stub_container1) { double('StubContainer1', detect: nil, compile: nil) }
    let(:stub_container2) { double('StubContainer2', detect: nil, compile: nil) }
    let(:stub_framework1) { double('StubFramework1', detect: nil) }
    let(:stub_framework2) { double('StubFramework2', detect: nil) }
    let(:stub_jre1) { double('StubJre1', detect: nil, compile: nil) }
    let(:stub_jre2) { double('StubJre2', detect: nil, compile: nil) }
    let(:stub_buildpack_version) { double('stub-buildpack-version', detect: nil, compile: nil) }

    before do
      YAML.stub(:load_file).and_call_original

      version_config_path = Pathname.new(File.expand_path('../../config/version.yml', File.dirname(__FILE__))).freeze
      YAML.stub(:load_file).with(version_config_path).and_return({})

      YAML.stub(:load_file).with(File.expand_path('config/licenses.yml')).and_return(nil)

      allow(LibertyBuildpack::Util::ConfigurationUtils).to receive(:load).and_call_original
      allow(LibertyBuildpack::Util::ConfigurationUtils)
        .to receive(:load).with('components').and_return(
          'containers' => ['Test::StubContainer1', 'Test::StubContainer2'],
          'frameworks' => ['Test::StubFramework1', 'Test::StubFramework2'],
          'jres'       => ['Test::StubJre1', 'Test::StubJre2']
        )

      allow_any_instance_of(LibertyBuildpack::BuildpackVersion).to receive(:version_string)
        .and_return('stub-buildpack-version')

      Test::StubContainer1.stub(:new).and_return(stub_container1)
      Test::StubContainer2.stub(:new).and_return(stub_container2)

      stub_container1.stub(:apps).and_return([])
      stub_container2.stub(:apps).and_return([])

      Test::StubFramework1.stub(:new).and_return(stub_framework1)
      Test::StubFramework2.stub(:new).and_return(stub_framework2)

      Test::StubJre1.stub(:new).and_return(stub_jre1)
      Test::StubJre2.stub(:new).and_return(stub_jre2)

      $stderr = StringIO.new
    end

    after do
      $stderr = STDERR
    end

    it 'should not write VCAP_SERVICES credentials as debug info',
       log_level: 'DEBUG', enable_log_file: true do
      ENV['VCAP_SERVICES'] = '{"type":[{"credentials":"VERY SECRET PHRASE","plain":"PLAIN DATA"}]}'
      log_content = with_buildpack do |buildpack|
        app_dir = File.dirname buildpack.instance_variable_get(:@lib_directory)
        File.read LibertyBuildpack::Diagnostics.get_buildpack_log app_dir
      end
      expect(log_content).not_to match(/VERY SECRET PHRASE/)
      expect(log_content).to match(/credentials.*PRIVATE DATA HIDDEN/)
      expect(log_content).to match(/PLAIN DATA/)
    end

    it 'should call detect on all non-JRE components and only one JRE component' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_container1.stub(:apps).and_return(['root/app1', 'root/app2'])
      stub_framework1.stub(:detect).and_return('stub-framework-1')
      stub_framework2.stub(:detect).and_return('stub-framework-2')
      stub_jre1.stub(:detect).and_return('stub-jre-1')
      stub_buildpack_version.stub(:detect).and_return('stub-buildpack-version')

      stub_container1.should_receive(:detect)
      stub_container2.should_receive(:detect)
      stub_framework1.should_receive(:detect)
      stub_framework2.should_receive(:detect)
      stub_jre1.should_receive(:detect)

      detected = with_buildpack(&:detect)
      expect(detected).to match_array(%w(stub-jre-1 stub-buildpack-version stub-framework-1 stub-framework-2 stub-container-1))
    end

    it 'should raise an error if more than one container can run an application' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_container2.stub(:detect).and_return('stub-container-2')

      with_buildpack { |buildpack| expect { buildpack.detect }.to raise_error(/stub-container-1, stub-container-2/) }
    end

    it 'should return no detections if no container can run an application' do
      detected = with_buildpack(&:detect)
      expect(detected).to be_empty
    end

    it 'should raise an error on compile if no container can run an application' do
      with_buildpack { |buildpack| expect { buildpack.compile }.to raise_error(/No supported application type/) }
    end

    it 'should raise an error on release if no container can run an application' do
      with_buildpack { |buildpack| expect { buildpack.release }.to raise_error(/No supported application type/) }
    end

    it 'should detect first JRE with non-null detect when more than one JRE can run an application' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_jre1.stub(:detect).and_return('stub-jre-1')
      stub_jre2.stub(:detect).and_return('stub-jre-2')
      stub_buildpack_version.stub(:detect).and_return('stub-buildpack-version')

      detected = with_buildpack(&:detect)
      expect(detected).to match_array(%w(stub-jre-1 stub-buildpack-version stub-container-1))
    end

    it 'should detect first JRE with non-null detect when more than one JRE can run an application' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_jre1.stub(:detect).and_return(nil)
      stub_jre2.stub(:detect).and_return('stub-jre-2')
      stub_buildpack_version.stub(:detect).and_return('stub-buildpack-version')

      detected = with_buildpack(&:detect)
      expect(detected).to match_array(%w(stub-jre-2 stub-buildpack-version stub-container-1))
    end

    it 'should omit buildpack version when version is unknown' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_jre1.stub(:detect).and_return('stub-jre-1')
      allow_any_instance_of(LibertyBuildpack::BuildpackVersion).to receive(:version_string).and_return(nil)

      detected = with_buildpack(&:detect)
      expect(detected).to match_array(%w(stub-jre-1 stub-container-1))
    end

    #    it 'should raise an error when none of the JREs return a non-null version for detect' do
    #      stub_container1.stub(:detect).and_return('stub-container-1')
    #      stub_jre1.stub(:detect).and_return(nil)
    #      stub_jre2.stub(:detect).and_return(nil)

    #      expect { with_buildpack { |buildpack| buildpack.detect}}.to raise_error SystemExit
    #      expect($stderr.string).to match(/JRE component did not return a valid version/)
    #    end

    it 'should call compile on matched components' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_container1.stub(:apps).and_return(['root/app1'])
      stub_framework1.stub(:detect).and_return('stub-framework-1')
      stub_jre1.stub(:detect).and_return('stub-jre-1')

      stub_container1.should_receive(:compile)
      stub_container2.should_not_receive(:compile)
      stub_framework1.should_receive(:compile)
      stub_framework2.should_not_receive(:compile)
      stub_jre1.should_receive(:compile)
      stub_jre2.should_not_receive(:compile)

      with_buildpack(&:compile)
    end

    describe 'Version Information' do

      it 'should display version info from git when the version.yml does not exist' do
        stub_container1.stub(:detect).and_return('stub-container-1')
        stub_container1.stub(:apps).and_return(['root/app1'])
        stub_jre1.stub(:detect).and_return('stub-jre-1')
        stub_jre1.stub(:compile).and_return(' ')

        git_dir = Pathname.new('.git').expand_path
        allow_any_instance_of(BuildpackVersion).to receive(:`)
          .with("git --git-dir=#{git_dir} rev-parse --short HEAD")
          .and_return('test-hash')
        allow_any_instance_of(BuildpackVersion).to receive(:`)
          .with("git --git-dir=#{git_dir} config --get remote.origin.url")
          .and_return('test-remote')

        expect { with_buildpack(&:compile) }.to output(/^-----> Liberty Buildpack Version: test-hash \| test-remote\#test-hash\n/).to_stdout
      end

      it 'should hide remote info and display version info from the version config file when version.yml exists' do
        Dir.mktmpdir do |root|
          File.stub(:exists?).with(anything).and_return(true)
          allow(LibertyBuildpack::Util::ConfigurationUtils).to receive(:load).with('version', true, true)
            .and_return('version' => '1234', 'remote' => '', 'hash' => '')

          stub_container1.stub(:detect).and_return('stub-container-1')
          stub_container1.stub(:apps).and_return(['root/app1'])
          stub_jre1.stub(:detect).and_return('stub-jre-1')
          YAML.stub(:load_file).with(File.expand_path('config/stubjre1.yml')).and_return(nil)
          YAML.stub(:load_file).with(File.expand_path('config/stubjre2.yml')).and_return(nil)
          YAML.stub(:load_file).with(File.expand_path('config/stubframework1.yml')).and_return(nil)
          YAML.stub(:load_file).with(File.expand_path('config/stubframework2.yml')).and_return(nil)
          YAML.stub(:load_file).with(File.expand_path('config/stubcontainer1.yml')).and_return(nil)
          YAML.stub(:load_file).with(File.expand_path('config/stubcontainer2.yml')).and_return(nil)
          stub_jre1.stub(:compile).and_return(' ')

          git_dir = Pathname.new('.git').expand_path
          allow_any_instance_of(BuildpackVersion).to receive(:system).with('which git > /dev/null').and_return(true)
          allow_any_instance_of(BuildpackVersion).to receive(:`)
            .with("git --git-dir=#{git_dir} rev-parse --short HEAD")
            .and_return('test-hash')
          allow_any_instance_of(BuildpackVersion).to receive(:`)
            .with("git --git-dir=#{git_dir} config --get remote.origin.url")
            .and_return('test-remote')

          expect { with_buildpack(&:compile) }.to output(/^-----> Liberty Buildpack Version: 1234\n/).to_stdout
        end
      end

    end # end of Version Info describe

    it 'should call release on matched components' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_container1.stub(:apps).and_return(['root/app1'])
      stub_framework1.stub(:detect).and_return('stub-framework-1')
      stub_jre1.stub(:detect).and_return('stub-jre-1')

      stub_container1.stub(:release).and_return('test-command')

      stub_container1.should_receive(:release)
      stub_container2.should_not_receive(:release)
      stub_framework1.should_receive(:release)
      stub_framework2.should_not_receive(:release)
      stub_jre1.should_receive(:release)
      stub_jre2.should_not_receive(:release)

      payload = with_buildpack(&:release)

      expect(payload).to eq({ 'addons' => [], 'config_vars' => {}, 'default_process_types' => { 'web' => 'test-command' } }.to_yaml)
    end

    it 'should load configuration file matching JRE class name' do
      stub_jre1.stub(:detect).and_return('stub-jre-1')
      File.stub(:exists?).with(File.expand_path('config/stubjre1.yml')).and_return(true)
      File.stub(:exists?).with(File.expand_path('config/stubjre2.yml')).and_return(false)
      File.stub(:exists?).with(File.expand_path('config/stubframework1.yml')).and_return(false)
      File.stub(:exists?).with(File.expand_path('config/stubframework2.yml')).and_return(false)
      File.stub(:exists?).with(File.expand_path('config/stubcontainer1.yml')).and_return(false)
      File.stub(:exists?).with(File.expand_path('config/stubcontainer2.yml')).and_return(false)
      File.stub(:exists?).with(File.expand_path('config/licenses.yml')).and_return(true)
      YAML.stub(:load_file).with(File.expand_path('config/stubjre1.yml')).and_return('x' => 'y')

      with_buildpack(&:detect)
    end

    it 'should raise error for bad configuration file that is missing container components' do
      stub_jre1.stub(:detect).and_return('stub-jre-1')
      allow(LibertyBuildpack::Util::ConfigurationUtils)
        .to receive(:load).with('components').and_return(
          'frameworks' => ['Test::StubFramework1', 'Test::StubFramework2'],
          'jres'       => ['Test::StubJre1', 'Test::StubJre2']
        )

      expect { with_buildpack(&:detect) }.to raise_error SystemExit
      expect($stderr.string).to match(/No components of type containers defined in components configuration/)
    end

    it 'should raise error for bad configuration file that is missing jre components' do
      stub_jre1.stub(:detect).and_return('stub-jre-1')
      allow(LibertyBuildpack::Util::ConfigurationUtils)
        .to receive(:load).with('components').and_return(
          'containers' => ['Test::StubContainer1', 'Test::StubContainer2'],
          'frameworks' => ['Test::StubFramework1', 'Test::StubFramework2']
        )

      expect { with_buildpack(&:detect) }.to raise_error SystemExit
      expect($stderr.string).to match(/No components of type jres defined in components configuration/)
    end

    it 'logs information about the git repository of a buildpack',
       log_level: 'DEBUG' do
      with_buildpack(&:detect)
      standard_error = $stderr.string
      expect(standard_error).to match(/git remotes/)
      expect(standard_error).to match(/git HEAD commit/)
    end

    it 'realises when buildpack is not stored in a git repository',
       log_level: 'DEBUG' do
      Dir.mktmpdir do |tmp_dir|
        Buildpack.stub(:git_dir).and_return(tmp_dir)
        with_buildpack(&:detect)
        expect($stderr.string).to match(/Buildpack is not stored in a git repository/)
      end
    end

    it 'handles exceptions correctly' do
      expect { with_buildpack { |buildpack| raise 'an exception' } }.to raise_error SystemExit
      expect($stderr.string).to match(/an exception/)
    end

    def with_buildpack(&block)
      LibertyBuildpack::Diagnostics::LoggerFactory.send :close # suppress warnings
      Dir.mktmpdir do |root|
        Buildpack.drive_buildpack_with_logger(File.join(root, APP_DIR), 'Error %s') do |buildpack|
          yield buildpack
        end
      end
    end

  end

end

module Test
  class StubContainer1
  end

  class StubContainer2
  end

  class StubJre1
  end

  class StubJre2
  end

  class StubFramework1
  end

  class StubFramework2
  end
end

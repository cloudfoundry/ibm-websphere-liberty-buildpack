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

require 'fileutils'
require 'liberty_buildpack/container/feature_manager'
require 'spec_helper'
require 'tmpdir'

module LibertyBuildpack::Container

  describe FeatureManager do

    FEATURE_REPOSITORY_FIXTURE_DIR = 'spec/fixtures/liberty_feature_repository'.freeze

    # buildpack feature manager code will call liberty's featureManager script,
    # this code takes the given script and copies it to the expected location
    # and filename. The provided script usually outputs the parameters passed-in
    # to it to a file with the same name as the script file with ".txt"
    # appended, and also outputs the value the real script file returns to
    # indicate success or failure to install features (depending on which
    # case is being tested).
    def set_up_feature_manager_script(root_dir, test_feature_manager_script_file)
      app_dir = File.join(root_dir, 'app')
      liberty_dir = File.join(app_dir, '.liberty')
      liberty_bin_dir = File.join(liberty_dir, 'bin')
      FileUtils.mkdir_p(liberty_bin_dir)
      feature_manager_script_file = File.join(liberty_bin_dir, 'installUtility')
      FileUtils.copy(test_feature_manager_script_file, feature_manager_script_file)
      system "chmod +x #{feature_manager_script_file}"
      [app_dir, liberty_dir]
    end

    # invoke the buildpack feature manager code that eventually calls the
    # liberty featureManager script, if the given configuration indicates it
    # should use the liberty repository.
    def call_feature_manager(app_dir, liberty_dir, configuration_file, server_xml_file)
      configuration = YAML.load_file(File.open(configuration_file))
      feature_manager = FeatureManager.new(app_dir, 'my-java-home', configuration)
      feature_manager.download_and_install_features(server_xml_file, liberty_dir)
    end

    def run(root_dir, repo_yml = nil, script_file = nil, server_xml_file = nil)
      # fixture files to be used.
      configuration_file = File.join(FEATURE_REPOSITORY_FIXTURE_DIR, repo_yml || 'use_default_repo.yml')
      feature_manager_script_file = File.join(FEATURE_REPOSITORY_FIXTURE_DIR, script_file || 'test_feature_manager_good_script')
      server_xml_file ||= File.join(FEATURE_REPOSITORY_FIXTURE_DIR, 'test_server.xml')

      # call feature manager using desired configuration and server.xml files.
      app_dir, liberty_dir = set_up_feature_manager_script(root_dir, feature_manager_script_file)
      call_feature_manager(app_dir, liberty_dir, configuration_file, server_xml_file)
      [app_dir, liberty_dir]
    end

    it 'should not use the liberty feature repository if not configured' do
      Dir.mktmpdir do |root_dir|
        liberty_dir = run(root_dir, 'no_repo.yml')[1]

        # check liberty's featureManager was not called.
        feature_manager_command_file = File.join(liberty_dir, 'bin', 'installUtility.txt')
        expect(File.exist?(feature_manager_command_file)).to eq(false)
      end
    end

    it 'should not use the liberty feature repository if configured with false' do
      Dir.mktmpdir do |root_dir|
        liberty_dir = run(root_dir, 'dont_use_repo.yml')[1]

        # check liberty's featureManager was not called.
        feature_manager_command_file = File.join(liberty_dir, 'bin', 'installUtility.txt')
        expect(File.exist?(feature_manager_command_file)).to eq(false)
      end
    end

    it 'should not use the liberty feature repository if configured with invalid value' do
      Dir.mktmpdir do |root_dir|
        liberty_dir = run(root_dir, 'junk_in_use_repo.yml')[1]

        # check liberty's featureManager was not called.
        feature_manager_command_file = File.join(liberty_dir, 'bin', 'installUtility.txt')
        expect(File.exist?(feature_manager_command_file)).to eq(false)
      end
    end

    it 'should use the liberty feature repository if configured true' do
      Dir.mktmpdir do |root_dir|
        app_dir, liberty_dir = run(root_dir)

        # check liberty's featureManager was called, with expected parameters.
        feature_manager_command_file = File.join(liberty_dir, 'bin', 'installUtility.txt')
        expect(File.exist?(feature_manager_command_file)).to eq(true)
        feature_manager_command = File.read feature_manager_command_file
        expect(feature_manager_command).to match(/jsp-2.2/)
        expect(feature_manager_command).to match(/featureOne/)
        expect(feature_manager_command).to match(/featureTwo/)
        expect(feature_manager_command).not_to match(/myUserFeature/)
        # look for : jvm args is ()
        expect(feature_manager_command).to match(/jvm args is \(\)/)
        # look for : java home is (<something>/my-java-home)
        expect(feature_manager_command).to match(/java home is \(.*\/my-java-home\)/)

        # check that a repository properties file was not created.
        repository_description_properties_file = File.join(app_dir, '.repository.description.properties')
        expect(File.exist?(repository_description_properties_file)).to eq(false)
      end
    end

    it 'should use the liberty feature repository with properties file if configured true with properties' do
      Dir.mktmpdir do |root_dir|
        app_dir, liberty_dir = run(root_dir, 'use_specified_repo.yml')

        # check liberty's featureManager was called, with expected parameters.
        feature_manager_command_file = File.join(liberty_dir, 'bin', 'installUtility.txt')
        expect(File.exist?(feature_manager_command_file)).to eq(true)
        feature_manager_command = File.read feature_manager_command_file
        expect(feature_manager_command).to match(/jsp-2.2/)
        expect(feature_manager_command).to match(/featureOne/)
        expect(feature_manager_command).to match(/featureTwo/)
        expect(feature_manager_command).not_to match(/myUserFeature/)
        # look for : jvm args is (-Drepository.description.url=file:///<something>/.repository.description.properties)
        # (enclosing quotes on path removed once set as environment variable).
        expect(feature_manager_command).to match(/jvm args is \(-DWLP_REPOSITORIES_PROPS=.*\.repository.description.properties\)/)
        # look for : java home is (<something>/my-java-home)
        expect(feature_manager_command).to match(/java home is \(.*\/my-java-home\)/)

        # check that a repository properties file was created, containing the expected properties.
        repository_description_properties_file = File.join(app_dir, '.repository.description.properties')
        expect(File.exist?(repository_description_properties_file)).to eq(true)
        repository_description_properties = File.read repository_description_properties_file
        expect(repository_description_properties).to match(/key1=value1/)
        expect(repository_description_properties).to match(/key2=value2/)
      end
    end

    it 'should throw an exception if liberty feature manager could not install features' do
      Dir.mktmpdir do |root_dir|
        # fixture files to be used.
        configuration_file = File.join(FEATURE_REPOSITORY_FIXTURE_DIR, 'use_default_repo.yml')
        feature_manager_script_file = File.join(FEATURE_REPOSITORY_FIXTURE_DIR, 'test_feature_manager_bad_script')
        server_xml_file = File.join(FEATURE_REPOSITORY_FIXTURE_DIR, 'test_server.xml')

        # call feature manager using desired configuration and server.xml files.
        app_dir, liberty_dir = set_up_feature_manager_script(root_dir, feature_manager_script_file)
        expect { call_feature_manager(app_dir, liberty_dir, configuration_file, server_xml_file) }.to raise_exception(/could not install required features/)
      end
    end

    it 'should install features from configDropins' do
      Dir.mktmpdir do |root_dir|
        liberty_dir = run(root_dir, nil, nil, 'spec/fixtures/container_liberty_single_server/server.xml')[1]

        # check liberty's featureManager was called, with expected parameters.
        feature_manager_command_file = File.join(liberty_dir, 'bin', 'installUtility.txt')
        expect(File.exist?(feature_manager_command_file)).to eq(true)

        feature_manager_command = File.read feature_manager_command_file
        expect(feature_manager_command).to match(/jsp-2.2/)
        expect(feature_manager_command).to match(/couchdb-1.0/)
        expect(feature_manager_command).to match(/mongodb-2.0/)
      end
    end

    context 'when JVM_ARGS is set by the user' do

      JVM_ARGS_KEY = 'JVM_ARGS'.freeze

      let(:prev_jvm_args) { 'user_jvm_args' }

      before do
        @previous_value = ENV[JVM_ARGS_KEY]
      end

      after do
        ENV[JVM_ARGS_KEY] = @previous_value
      end

      it 'should not process preexisting JVM_ARGS when using the liberty feature repository' do
        ENV[JVM_ARGS_KEY] = prev_jvm_args

        Dir.mktmpdir do |root_dir|
          liberty_dir = run(root_dir)[1]

          # check liberty's featureManager was called, with expected parameters.
          feature_manager_command_file = File.join(liberty_dir, 'bin', 'installUtility.txt')
          expect(File.exist?(feature_manager_command_file)).to eq(true)
          feature_manager_command = File.read feature_manager_command_file
          expect(feature_manager_command).to match(/jvm args is \(\)/)
        end
      end

      it 'should restore JVM_ARGS value when using the liberty feature repository' do
        ENV[JVM_ARGS_KEY] = prev_jvm_args

        Dir.mktmpdir do |root_dir|
          run(root_dir)

          # check that the JVM_ARGS has the same value from prior to running feature manager
          expect(ENV['JVM_ARGS']).to match(prev_jvm_args)
        end
      end

    end # end of JVM_ARGS context

  end # describe

end # module

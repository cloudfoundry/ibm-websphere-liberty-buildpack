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
require 'liberty_buildpack/framework/env'

module LibertyBuildpack::Framework

  describe Env do

    it 'should detect with env configuration' do
      detected = Env.new(
        app_dir: 'root',
        environment: {},
        configuration: { 'foo' => 'http://bar.com' }
      ).detect

      expect(detected).to eq('env')
    end

    it 'should not detect with empty env configuration' do
      detected = Env.new(
        app_dir: 'root',
        environment: {},
        configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect with nil env configuration' do
      detected = Env.new(
        app_dir: 'root',
        environment: {},
        configuration: nil
      ).detect

      expect(detected).to be_nil
    end

    it 'should create env.sh with env configuration' do
      Dir.mktmpdir do |root|
        Env.new(
          app_dir: root,
          environment: {},
          configuration: { 'foo' => 'bar', 'rmu' => 'http://doesnotexist.com', 'bar' => 'a b c', ' ' => 'a', 'b' => ' ' }
        ).compile

        env_file = File.join(root, '.profile.d', 'env.sh')
        expect(File.file?(env_file)).to eq(true)

        env_contents = File.readlines(env_file)
        expect(env_contents.size).to eq(4)
        expect(env_contents).to include(/export foo="bar"/)
        expect(env_contents).to include(%r{export rmu=\"http://doesnotexist.com\"})
        expect(env_contents).to include(/export bar="a b c"/)
        expect(env_contents).to include(/export b=" "/)
      end
    end

    it 'should create env.sh with env configuration from profile' do
      Dir.mktmpdir do |root|
        yml = %(---
        foo: bar
        rmu: http://doesnotexist.com
        profile_1:
          foo: car
          bart: simpson)

        Env.new(
          app_dir: root,
          environment: { 'IBM_ENV_PROFILE' => 'profile_1' },
          configuration: YAML.load(yml)
        ).compile

        env_file = File.join(root, '.profile.d', 'env.sh')
        expect(File.file?(env_file)).to eq(true)

        env_contents = File.readlines(env_file)
        expect(env_contents.size).to eq(3)
        expect(env_contents).to include(/export foo="car"/)
        expect(env_contents).to include(%r{export rmu=\"http://doesnotexist.com\"})
        expect(env_contents).to include(/export bart="simpson"/)
      end
    end

    it 'should create env.sh with env configuration from list of profiles' do
      Dir.mktmpdir do |root|
        yml = %(---
        foo: bar
        rmu: http://doesnotexist.com
        my_profile:
          disco: stu
          bart: man
        profile_1:
          foo: car
          bart: simpson
        profile-2:
          bar: no cow)

        Env.new(
          app_dir: root,
          environment: { 'IBM_ENV_PROFILE' => 'profile_1, bad_profile, my_profile' },
          configuration: YAML.load(yml)
        ).compile

        env_file = File.join(root, '.profile.d', 'env.sh')
        expect(File.file?(env_file)).to eq(true)

        env_contents = File.readlines(env_file)
        expect(env_contents.size).to eq(4)
        expect(env_contents).to include(/export foo="car"/)
        expect(env_contents).to include(%r{export rmu=\"http://doesnotexist.com\"})
        expect(env_contents).to include(/export bart="man"/)
        expect(env_contents).to include(/export disco="stu"/)
      end
    end

    it 'should create env.sh with env configuration from profile using BLUEMIX_REGION' do
      Dir.mktmpdir do |root|
        yml = %(---
        foo: bar
        rmu: http://doesnotexist.com
        "ibm:profile:1":
          foo: car
          bart: simpson)

        Env.new(
          app_dir: root,
          environment: { 'BLUEMIX_REGION' => 'ibm:profile:1' },
          configuration: YAML.load(yml)
        ).compile

        env_file = File.join(root, '.profile.d', 'env.sh')
        expect(File.file?(env_file)).to eq(true)

        env_contents = File.readlines(env_file)
        expect(env_contents.size).to eq(3)
        expect(env_contents).to include(/export foo="car"/)
        expect(env_contents).to include(%r{export rmu=\"http://doesnotexist.com\"})
        expect(env_contents).to include(/export bart="simpson"/)
      end
    end

  end
end

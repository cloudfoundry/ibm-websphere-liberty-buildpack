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
        configuration: { 'foo' => 'http://bar.com' }
      ).detect

      expect(detected).to eq('env')
    end

    it 'should not detect with empty env configuration' do
      detected = Env.new(
        app_dir: 'root',
        configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect with nil env configuration' do
      detected = Env.new(
        app_dir: 'root',
        configuration: nil
      ).detect

      expect(detected).to be_nil
    end

    it 'should create env.sh with env configuration' do
      Dir.mktmpdir do |root|
        Env.new(
          app_dir: root,
          configuration: { 'foo' => 'bar', 'rmu' => 'http://doesnotexist.com', 'bar' => 'a b c', ' ' => 'a', 'b' => ' ' }
        ).compile

        env_file = File.join(root, '.profile.d', 'env.sh')
        expect(File.file?(env_file)).to eq(true)

        env_contents = File.readlines(env_file)
        expect(env_contents.size).to eq(4)
        expect(env_contents).to include(/export foo.*=.*"bar"/)
        expect(env_contents).to include(%r(export rmu.*=.*\"http://doesnotexist.com\"))
        expect(env_contents).to include(/export bar.*=.*"a b c"/)
        expect(env_contents).to include(/export b.*=.*" "/)
      end
    end

  end
end

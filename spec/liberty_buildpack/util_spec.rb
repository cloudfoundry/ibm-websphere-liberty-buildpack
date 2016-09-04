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
require 'liberty_buildpack/util'

module LibertyBuildpack

  describe Util do

    describe 'safe_vcap_services' do

      it 'should not fail on nil' do
        expect(LibertyBuildpack::Util.safe_vcap_services(nil)).to eq(nil)
      end

      it 'should not fail on empty objects' do
        expect(LibertyBuildpack::Util.safe_vcap_services('')).to eq('')
        expect(LibertyBuildpack::Util.safe_vcap_services({})).to eq({})
        expect(LibertyBuildpack::Util.safe_vcap_services([])).to eq([])
      end

      it 'should not fail on none JSON strings' do
        expect(LibertyBuildpack::Util.safe_vcap_services('wrong')).to eq('wrong')
      end

      it 'should not fail on none-empty arrays' do
        expect(LibertyBuildpack::Util.safe_vcap_services(['one'])).to eq(['one'])
      end

      it 'should not fail on maps containing nil as value' do
        expect(LibertyBuildpack::Util.safe_vcap_services('one' => nil)).to eq('one' => nil)
        expect(LibertyBuildpack::Util.safe_vcap_services('{"one": null}')).to eq('{"one":null}')
      end

      it 'should mask "credential" entries' do
        expect(LibertyBuildpack::Util.safe_vcap_services('database' => [{ 'credentials' => { 'identity' => 'VERY SECRET PHRASE' } }])).to eq('database' => [{ 'credentials' => ['PRIVATE DATA HIDDEN'] }])
      end

      it 'should not mask than than "credential" entries' do
        expect(LibertyBuildpack::Util.safe_vcap_services('database' => [{ 'name' => 'PLAIN NAME' }])).to eq('database' => [{ 'name' => 'PLAIN NAME' }])
      end

      it 'should not alter input variable' do
        input = { 'database' => [{ 'credentials' => { 'identity' => 'VERY SECRET PHRASE' } }] }
        output = LibertyBuildpack::Util.safe_vcap_services(input)
        expect(output).not_to eq(input)
      end
    end

    describe 'safe_service_data' do

      it 'should not fail on nil' do
        expect(LibertyBuildpack::Util.safe_service_data(nil)).to eq(nil)
      end

      it 'should not fail on empty objects' do
        expect(LibertyBuildpack::Util.safe_service_data('')).to eq('')
        expect(LibertyBuildpack::Util.safe_service_data([])).to eq([])
        expect(LibertyBuildpack::Util.safe_service_data({})).to eq({})
      end

      it 'should not fail on non map array elements' do
        expect(LibertyBuildpack::Util.safe_service_data(['one'])).to eq(['one'])
        expect(LibertyBuildpack::Util.safe_service_data([['one']])).to eq([['one']])
      end

      it 'should mask "credential" entries' do
        expect(LibertyBuildpack::Util.safe_service_data([{ 'credentials' => 'VERY SECRET PHRASE' }])).to eq([{ 'credentials' => ['PRIVATE DATA HIDDEN'] }])
      end

      it 'should not mask other than "credential" entries' do
        expect(LibertyBuildpack::Util.safe_service_data([{ 'data' => 'PLAIN DATA' }])).to eq([{ 'data' => 'PLAIN DATA' }])
      end

      it 'hould not alter input variable' do
        input = [{ 'credentials' => 'VERY SECRET PHRASE' }]
        output = LibertyBuildpack::Util.safe_service_data(input)
        expect(output).not_to eq(input)
      end

    end

    describe 'safe_credential_properties' do
      it 'should not fail on nil' do
        expect(LibertyBuildpack::Util.safe_credential_properties(nil)).to eq('')
      end

      it 'should not fail on empty string' do
        expect(LibertyBuildpack::Util.safe_credential_properties('')).to eq('')
      end

      it 'should mask cloud.services.*.connection.* values' do
        expect(LibertyBuildpack::Util.safe_credential_properties("<variable name='cloud.services.data.connection.identity' value='VERY SECRET PHRASE'/>")).to eq("<variable name='cloud.services.data.connection.identity' value='[PRIVATE DATA HIDDEN]'/>")
      end

      it 'should not mask other than cloud.services.*.connection.* entries' do
        expect(LibertyBuildpack::Util.safe_credential_properties("<variable name='cloud.services.data.name' value='PLAIN NAME'/>")).to eq("<variable name='cloud.services.data.name' value='PLAIN NAME'/>")
      end

      it 'should mask only cloud.services.*.connection.* entries' do
        input = [
          "<variable name='cloud.services.data.name' value='PLAIN NAME'/>",
          "<variable name='cloud.services.data.connection.identity' value='VERY SECRET PHRASE'/>",
          "<variable name='cloud.services.data.version' value='PLAIN VERSION'/>"
        ]

        expected = [
          input[0],
          "<variable name='cloud.services.data.connection.identity' value='[PRIVATE DATA HIDDEN]'/>",
          input[2]
        ]

        expect(LibertyBuildpack::Util.safe_credential_properties(input)).to eq(expected.to_s)
      end

      it 'should not alter input variable' do
        input = "<variable name='cloud.services.data.connection.identity' value='VERY SECRET PHRASE'/>"
        output = LibertyBuildpack::Util.safe_credential_properties(input)
        expect(output).not_to eq(input)
      end

    end

    describe 'safe_heroku_env' do

      it 'should mask all variables ending in _URI and _URL' do
        safe_env = { 'SECRET_URL' => 'secret URL', 'SECRET_URI' => 'secret URI' }
        LibertyBuildpack::Util.safe_heroku_env!(safe_env)
        expect(safe_env).to eq('SECRET_URL' => '[PRIVATE DATA HIDDEN]', 'SECRET_URI' => '[PRIVATE DATA HIDDEN]')
      end

      it 'should not mask other variables than the one ending in _URI and _URL' do
        safe_env = { 'GOOD_VAR' => 'good data' }
        LibertyBuildpack::Util.safe_heroku_env!(safe_env)
        expect(safe_env).to eq('GOOD_VAR' => 'good data')
      end

    end

  end

end

# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
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
require 'liberty_buildpack/util/heroku'

module LibertyBuildpack::Util

  describe 'Detect' do

    after (:each) do
      ENV.delete('DYNO')
    end

    it 'Heroku environment' do
      ENV['DYNO'] = 'web.1'
      expect(Heroku.heroku?).to be_true
    end

    it 'Non Heroku environment' do
      ENV.delete('DYNO')
      expect(Heroku.heroku?).to be_false
    end

  end

  describe 'VCAP_SERVICES' do

    def check_database_url(vcap_services)
      services = vcap_services['DATABASE_URL']
      expect(services).to have(1).items
      expect(services[0]['name']).to match('database')
      credentials = services[0]['credentials']
      expect(credentials).to have(9).items
      expect(credentials['host']).to match('foo')
      expect(credentials['hostname']).to match('foo')
      expect(credentials['port']).to eq(500)
      expect(credentials['user']).to match('u')
      expect(credentials['username']).to match('u')
      expect(credentials['password']).to match('p')
      expect(credentials['name']).to match('bar')
      expect(credentials['uri']).to match('http://u:p@foo:500/bar')
      expect(credentials['url']).to match('http://u:p@foo:500/bar')
      tags = services[0]['tags']
      expect(tags).to be_nil
    end

    def check_postgresql(vcap_services, expected_name)
      services = vcap_services['HEROKU_POSTGRESQL_RED_URL']
      expect(services).to have(1).items
      expect(services[0]['name']).to match(expected_name)
      credentials = services[0]['credentials']
      expect(credentials).to have(4).items
      expect(credentials['host']).to match('doesnotexist.xyz')
      expect(credentials['hostname']).to match('doesnotexist.xyz')
      expect(credentials['uri']).to match('postgre://doesnotexist.xyz')
      expect(credentials['url']).to match('postgre://doesnotexist.xyz')
      tags = services[0]['tags']
      expect(tags).to include('postgresql')
    end

    def check_mysql(vcap_services, expected_name)
      services = vcap_services['CLEARDB_DATABASE_URL']
      expect(services).to have(1).items
      expect(services[0]['name']).to match(expected_name)
      credentials = services[0]['credentials']
      expect(credentials).to have(8).items
      expect(credentials['host']).to match('nnn.com')
      expect(credentials['hostname']).to match('nnn.com')
      expect(credentials['user']).to match('ggg')
      expect(credentials['username']).to match('ggg')
      expect(credentials['password']).to match('hhh')
      expect(credentials['name']).to match('mmmm')
      expect(credentials['uri']).to match('mysql://ggg:hhh@nnn.com/mmmm')
      expect(credentials['url']).to match('mysql://ggg:hhh@nnn.com/mmmm')
      tags = services[0]['tags']
      expect(tags).to include('mysql')
    end

    def check_bad(vcap_services)
      services = vcap_services['BAD_URL']
      expect(services).to be_nil
    end

    it 'generate without service mappings' do
      env = {}
      env['DATABASE_URL'] = 'http://u:p@foo:500/bar'
      env['HEROKU_POSTGRESQL_RED_URL'] = 'postgre://doesnotexist.xyz'
      env['CLEARDB_DATABASE_URL'] = 'mysql://ggg:hhh@nnn.com/mmmm'
      env['BAD_URL'] = '://badurl.xyz'

      vcap_services = Heroku.new.generate_vcap_services(env)

      # verify DATABASE_URL
      check_database_url(vcap_services)

      # verify HEROKU_POSTGRESQL_RED_URL
      check_postgresql(vcap_services, 'postgresql.red')

      # verify CLEARDB_DATABASE_URL
      check_mysql(vcap_services, 'cleardb')

      # verify BAD_URL
      check_bad(vcap_services)
    end

    it 'generate with service mappings' do
      env = {}
      env['DATABASE_URL'] = 'http://u:p@foo:500/bar'
      env['HEROKU_POSTGRESQL_RED_URL'] = 'postgre://doesnotexist.xyz'
      env['CLEARDB_DATABASE_URL'] = 'mysql://ggg:hhh@nnn.com/mmmm'
      env['BAD_URL'] = '://badurl.xyz'

      env['SERVICE_NAME_MAP'] = 'HEROKU_POSTGRESQL_RED_URL=myDatabase; CLEARDB_DATABASE_URL = mysqlDb'

      vcap_services = Heroku.new.generate_vcap_services(env)

      # verify DATABASE_URL
      check_database_url(vcap_services)

      # verify HEROKU_POSTGRESQL_RED_URL
      check_postgresql(vcap_services, 'myDatabase')

      # verify CLEARDB_DATABASE_URL
      check_mysql(vcap_services, 'mysqlDb')

      # verify BAD_URL
      check_bad(vcap_services)
    end

  end

end

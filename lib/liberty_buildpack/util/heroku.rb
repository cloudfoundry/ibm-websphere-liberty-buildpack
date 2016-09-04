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

require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/util'

module LibertyBuildpack::Util

  # Heroku utilities.
  class Heroku

    # Detects Heroku environment.
    #
    # @return [Boolean] +true+ if running on Heroku. +False+ otherwise.
    def self.heroku?
      ENV['DYNO'].nil? ? false : true
    end

    # Initialize
    def initialize
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
    end

    # Generates VCAP_SERVICES style map from a map that represents the environment variables
    # as set on Heroku. Each bound service on Heroku sets one or more environment variables that
    # specifies the location (in the form of a URL) of the service.
    #
    # @param [Hash] env - the map with environment variables
    # @return [Hash] VCAP_SERVICES style map
    def generate_vcap_services(env)
      vcap_services = {}
      service_name_map = parse_service_name_map(env)
      env.each do |key, value|
        next unless key.end_with?(URL_SUFFIX, URI_SUFFIX)
        if key.start_with?(POSTGRESQL_PREFIX)
          type, service = handle_postgresql(key, value, service_name_map)
        elsif key.start_with?(CLEARDB_PREFIX)
          type, service = handle_cleardb(key, value, service_name_map)
        elsif key.start_with?(MONGOLAB_PREFIX)
          type, service = handle_mongodb(key, value, service_name_map, 'mongolab')
        elsif key.start_with?(MONGOHQ_PREFIX)
          type, service = handle_mongodb(key, value, service_name_map, 'mongohq')
        elsif key.start_with?(MONGOSOUP_PREFIX)
          type, service = handle_mongodb(key, value, service_name_map, 'mongosoup')
        else
          type = key
          service = {}
          service['name'] = service_name_map[key] || generate_name(key)
          service['credentials'] = create_default_credentials(key, value)
        end

        vcap_services[type] = [service]
      end
      vcap_services
    end

    private

    URL_SUFFIX = '_URL'.freeze
    URI_SUFFIX = '_URI'.freeze
    POSTGRESQL_PREFIX = 'HEROKU_POSTGRESQL_'.freeze
    CLEARDB_PREFIX = 'CLEARDB_DATABASE_'.freeze
    MONGOHQ_PREFIX = 'MONGOHQ_'.freeze
    MONGOLAB_PREFIX = 'MONGOLAB_'.freeze
    MONGOSOUP_PREFIX = 'MONGOSOUP_'.freeze

    def handle_postgresql(key, value, service_name_map)
      type = 'postgresql'
      service = {}
      service['name'] = service_name_map[key] || type + '.' + key[POSTGRESQL_PREFIX.size..-URL_SUFFIX.size - 1].downcase
      service['tags'] = ['postgresql']
      credentials = {}
      credentials['uri'] = value
      service['credentials'] = credentials
      [key, service]
    end

    def handle_cleardb(key, value, service_name_map)
      type = 'cleardb'
      service = {}
      service['name'] = service_name_map[key] || type
      service['tags'] = ['mysql']
      credentials = {}
      credentials['uri'] = value
      service['credentials'] = credentials
      [key, service]
    end

    def handle_mongodb(key, value, service_name_map, type)
      service = {}
      service['name'] = service_name_map[key] || type
      service['tags'] = ['mongodb']
      credentials = {}
      credentials['url'] = value
      service['credentials'] = credentials
      [key, service]
    end

    def create_default_credentials(key, value)
      credentials = {}
      begin
        uri = URI.parse(value)
        credentials['host'] = credentials['hostname'] = uri.host
        credentials['port'] = uri.port unless uri.port.nil?
        credentials['user'] = credentials['username'] = uri.user unless uri.user.nil?
        credentials['password'] = uri.password unless uri.password.nil?
        credentials['name'] = uri.path[1..-1]  unless uri.path[1..-1].nil?
      rescue URI::InvalidURIError
        @logger.debug("unable to parse #{key}")
      end
      credentials['uri'] = credentials['url'] = value
      credentials
    end

    def generate_name(url)
      # remove _URL at the end & downcase it
      name = url[0..-URL_SUFFIX.size - 1].downcase
      name
    end

    def parse_service_name_map(env)
      name_map = env['SERVICE_NAME_MAP']
      map = {}
      unless name_map.nil?
        name_map.split(',').each do |value|
          key_value = value.split('=')
          map[key_value[0].strip] = key_value[1].strip if key_value.size == 2
        end
      end
      map
    end
  end

end

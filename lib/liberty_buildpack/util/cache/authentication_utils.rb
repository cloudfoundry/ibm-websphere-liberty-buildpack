# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2015 the original author or authors.
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

require 'liberty_buildpack/util/configuration_utils'

module LibertyBuildpack::Util::Cache

  # Utilites to handle sites requiring authentication
  # Authentication is specified in config/auth.xml file associating URL to
  # authorization data. Authorization could be the string usable in
  # 'Authorization' header or a map containing 'username' and 'password' keys
  # to use for Basic authentication.
  #
  # For example:
  # ---
  # https://basic.auth.com/:
  #   username: testuser
  #   password: testpass
  # http://generic.auth.com/files: Bearer AbCdEf123456
  #
  class AuthenticationUtils

    private_class_method :new

    class << self

      # Checks config/auth.yml for authorization data associated with
      # the URL and updates request accordingly.
      #
      # @param [Net::HTTPHeader] request causing authentication exception
      # @param [String] URL the authorization is required for
      # @return [Boolean] true if 'Authorization' header was updated
      def authorization(request, url)
        unless request.key? HTTP_Authorization
          value = authorization_value(url)
          if value.instance_of? String
            request[HTTP_Authorization] = value
            return true
          elsif (value.instance_of? Hash) && (value.key? USER_KEY) && (value.key? PASS_KEY)
            request.basic_auth value[USER_KEY], value[PASS_KEY]
            return true
          end
        end
        false
      end

      private

      @@auth_config = nil

      HTTP_Authorization = 'Authorization'.freeze

      USER_KEY = 'username'.freeze

      PASS_KEY = 'password'.freeze

      # Loads authentication information from config/auth.yml as a map from
      # URL substring to the authorization object and returns the best match
      # for the provided URL.
      #
      # @param [String] URL the authorization is required for
      # @return [Stringi, Hash] the Authorization data or nil if not found
      def authorization_value(url)
        unless @@auth_config
          # Load auth.yml and make sure the information is not logged
          @@auth_config = LibertyBuildpack::Util::ConfigurationUtils.load('auth', true, false)
          # Sort keys by size with longest first.
          @@sorted_keys = @@auth_config.keys.sort { |a, b| b.size <=> a.size }
        end

        # Find the longest substring of the url among keys
        key = @@sorted_keys.find { |k| url.start_with? k }
        key ? @@auth_config[key] : nil
      end

    end

  end

end

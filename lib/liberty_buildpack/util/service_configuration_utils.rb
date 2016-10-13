# Encoding: utf-8
# Cloud Foundry Java Buildpack
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2015-2016 the original author or authors.
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

require 'pathname'
require 'liberty_buildpack/util'
require 'liberty_buildpack/diagnostics/logger_factory'
require 'shellwords'
require 'yaml'

module LibertyBuildpack
  module Util

    # Utility for loading configuration
    class ServiceConfigurationUtils

      private_class_method :new

      class << self

        # Loads a configuration file from the service buildpack configuration directory.  If the configuration file does not
        # exist, returns an empty.
        #
        # @param [String] key the identifier of the configuration to load
        # @param [Boolean] clean_nil_values whether empty/nil values should be removed along with their keys from the
        #                                  returned configuration.
        # @param [Boolean] should_log whether the contents of the configuration file should be logged.  This value
        #                             should be left to its default and exists to allow the logger to use the utility.
        # @return [Hash] the configuration or an empty hash if the configuration file does not exist
        def load_user_conf(key, config, file, clean_nil_values, should_log)
          var_name = environment_variable_name(key)
          user_provided = ENV[var_name]

          logger.debug { "loading service config for #{key} from #{file}" } if should_log
          config[key] = File.open(file, 'r:utf-8') { |yf| YAML.load(yf) }

          if user_provided
            begin
              user_provided_value = YAML.load(user_provided)
              config[key] = merge_configuration(config[key], user_provided_value, var_name, should_log)
            rescue Psych::SyntaxError => ex
              raise "User service configuration value in environment variable #{var_name} has invalid syntax: #{ex}"
            end
            logger.debug { "Service configuration from #{file} modified with: #{user_provided}" } if should_log
          end
          clean_nil_values config[key] if clean_nil_values && !config[key].nil?
          config[key]
        end

        private

        ENVIRONMENT_VARIABLE_PATTERN = 'LBP_SERVICE_CONFIG_'.freeze

        def clean_nil_values(configuration)
          configuration.each do |key, value|
            if value.is_a?(Hash)
              configuration[key] = clean_nil_values value
            elsif value.nil?
              configuration.delete key
            end
          end
          configuration
        end

        def merge_configuration(configuration, user_provided_value, var_name, should_log)
          if user_provided_value.is_a?(Hash)
            configuration = do_merge(configuration, user_provided_value, should_log)
          elsif user_provided_value.is_a?(Array)
            user_provided_value.each { |new_prop| configuration = do_merge(configuration, new_prop, should_log) }
          else
            raise "User configuration value in environment variable #{var_name} is not valid: #{user_provided_value}"
          end
          configuration
        end

        def do_merge(hash_v1, hash_v2, should_log)
          hash_v2.each do |key, value|
            if hash_v1.key? key
              hash_v1[key] = do_resolve_value(key, hash_v1[key], value, should_log)
            elsif should_log
              logger.warn { "User config value for '#{key}' is not valid, existing property not present" }
            end
          end
          hash_v1
        end

        def do_resolve_value(key, v1, v2, should_log)
          return do_merge(v1, v2, should_log) if v1.is_a?(Hash) && v2.is_a?(Hash)
          return v2 if !v1.is_a?(Hash) && !v2.is_a?(Hash)
          logger.warn { "User config value for '#{key}' is not valid, must be of a similar type" } if should_log
          v1
        end

        def environment_variable_name(config_name)
          ENVIRONMENT_VARIABLE_PATTERN + config_name.upcase
        end

        def logger
          LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
        end

      end

    end

  end
end

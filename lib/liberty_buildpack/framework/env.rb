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

require 'liberty_buildpack/framework'
require 'liberty_buildpack/util/dash_case'
require 'liberty_buildpack/diagnostics/logger_factory'

module LibertyBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for contributing custom environment variables
  # to an application at runtime.
  class Env

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context = {})
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @configuration = context[:configuration]
      @app_dir = context[:app_dir]
      @environment = context[:environment]
    end

    # Detects whether the buildpack provides custom environment variables.
    #
    # @return [String] returns +env+ if custom environment variables are set.
    def detect
      configuration? ? Env.to_s.dash_case : nil
    end

    # Create .profile.d/env.sh with the custom environment variables.
    #
    # @return [void]
    def compile
      profiled_dir = File.join(@app_dir, '.profile.d')
      FileUtils.mkdir_p(profiled_dir)

      variables = {}
      # apply default variables
      copy_variables(variables, @configuration)
      # apply profiles
      profiles.each do |profile|
        profile = profile.strip
        profile_variables = @configuration[profile]
        if profile_variables.nil?
          @logger.debug { "Environment variable profile #{profile} not found." }
        elsif profile_variables.is_a? Hash
          @logger.debug { "Applying environment variable profile #{profile}." }
          copy_variables(variables, profile_variables)
        end
      end

      @logger.debug { "Buildpack environment variables: #{variables}" }

      env_file_name = File.join(profiled_dir, 'env.sh')
      env_file = File.new(env_file_name, 'w')
      variables.each do |key, value|
        env_file.puts("export #{key}=\"#{value}\"")
      end
      env_file.close
    end

    # No op.
    #
    # @return [void]
    def release
    end

    private

    def configuration?
      !@configuration.nil? && @configuration.size > 0 && !'---'.eql?(@configuration)
    end

    def copy_variables(variables, configuration)
      configuration.each do |key, value|
        key = key.strip
        variables[key] = value unless value.is_a?(Hash) || value.is_a?(Array) || key.empty?
      end
    end

    def profiles
      profiles_var = @environment['IBM_ENV_PROFILE']
      if profiles_var.nil?
        region = @environment['BLUEMIX_REGION']
        region.nil? ? [] : [region]
      else
        profiles_var.split(',')
      end
    end
  end

end

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
require 'shellwords'

module LibertyBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for contributing custom Java options to an application
  # at runtime.
  class JavaOpts

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context = {})
      @java_opts = context[:java_opts]
      @configuration = context[:configuration]
      @jvm_type = context[:jvm_type]
      @app_dir = context[:app_dir]
      @environment = context[:environment]
    end

    # Detects whether this application contributes Java options.
    #
    # @return [String] returns +java-opts+ if Java options have been set by the user
    def detect
      supports_configuration? || supports_environment? ? JavaOpts.to_s.dash_case : nil
    end

    # Ensures that none of the Java options specify memory configurations
    #
    # @return [void]
    def compile
      parsed_java_opts.each do |option|
        raise "Java option '#{option}' configures a memory region.  Use JRE configuration for this instead." if memory_option? option
      end
    end

    # Adds the contents of +java.opts+ to the +context[:java_opts]+ for use when running the application
    #
    # @return [void]
    def release
      @java_opts.concat parsed_java_opts
    end

    private

    CONFIGURATION_PROPERTY = 'java_opts'.freeze

    ENVIRONMENT_PROPERTY = 'from_environment'.freeze

    ENVIRONMENT_VARIABLE = 'JAVA_OPTS'.freeze

    def memory_option?(option)
      option =~ /-Xms/ || option =~ /-Xmx/ || option =~ /-XX:MaxMetaspaceSize/ || option =~ /-XX:MaxPermSize/ ||
        option =~ /-Xss/ || option =~ /-XX:MetaspaceSize/ || option =~ /-XX:PermSize/ if !@jvm_type.nil? && 'openjdk'.casecmp(@jvm_type) == 0
    end

    def parsed_java_opts
      parsed_java_opts = []

      parsed_java_opts.concat @configuration[CONFIGURATION_PROPERTY].shellsplit if supports_configuration?
      parsed_java_opts.concat @environment[ENVIRONMENT_VARIABLE].shellsplit if supports_environment?

      parsed_java_opts.map { |java_opt| java_opt.gsub(/([\s])/, '\\\\\1') }
    end

    def supports_configuration?
      @configuration.key?(CONFIGURATION_PROPERTY) && !@configuration[CONFIGURATION_PROPERTY].nil?
    end

    def supports_environment?
      @configuration[ENVIRONMENT_PROPERTY] && @environment.key?(ENVIRONMENT_VARIABLE)
    end

  end

end

# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013 the original author or authors.
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

require 'liberty_buildpack/container'
require 'liberty_buildpack/util/dash_case'
require 'liberty_buildpack/util/java_main_utils'
require 'liberty_buildpack/util'
require 'liberty_buildpack/container/container_utils'
require 'liberty_buildpack/container/common_paths'
require 'fileutils'

module LibertyBuildpack::Container
  # Encapsulates the detect, compile, and release functionality for Java-Main applications.
  class JavaMain

    include LibertyBuildpack::Util

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [CommonPaths] :common_paths the set of paths common across components that components should reference
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
      @common_paths = context[:common_paths] || CommonPaths.new
      @configuration = context[:configuration]
    end

    # Detects whether this application is a Java-Main application.
    #
    # @return [String] returns +Java-Main+ if the MANIFEST.MF of the application contains the Java-Main tag.
    def detect
      if main_class
        @common_paths.relative_location = '../'
        ['JAR', JavaMain.to_s.dash_case]
      end
    end

    # Prepares the application to run.
    #
    # @return [void]
    def compile
      overlay_java
    end

    # Creates the command to run the Java application.
    #
    # @return [String] the command to run the application.
    def release
      [
        "#{java_home}/jre/bin/java",
        manifest_class_path,
        @java_opts.join(' '),
        main_class,
        arguments,
        port
      ].flatten.compact.join(' ')
    end

    private

    ARGUMENTS_PROPERTY = 'arguments'.freeze

    CLASS_PATH_PROPERTY = 'Class-Path'.freeze

    RESOURCES_DIR = 'resources'.freeze

    JAVA_DIR = '.java'.freeze

    JAVA_OVERLAY_DIR  = '.java-overlay'.freeze

    def java_home
      File.join('$PWD', @java_home)
    end

    def arguments
      @configuration[ARGUMENTS_PROPERTY]
    end

    def main_class
      LibertyBuildpack::Util::JavaMainUtils.main_class(@app_dir, @configuration)
    end

    def manifest_class_path
      values = LibertyBuildpack::Util::JavaMainUtils.manifest(@app_dir)[CLASS_PATH_PROPERTY]
      values.nil? ? [] : "-cp #{values.split(' ').map { |value| File.join('$PWD', value) }.join(':')}"
    end

    def port
      main_class =~ /^org\.springframework\.boot\.loader\.(?:[JW]ar|Properties)Launcher$/ ? '--server.port=$PORT' : nil
    end

    def overlay_java
      overlay_src = File.join(@app_dir, RESOURCES_DIR, JAVA_OVERLAY_DIR, JAVA_DIR)
      if File.exists?(overlay_src)
        print "Overlaying java from #{overlay_src}\n"
        FileUtils.cp_r(overlay_src, @app_dir)
      end
    end

  end
end

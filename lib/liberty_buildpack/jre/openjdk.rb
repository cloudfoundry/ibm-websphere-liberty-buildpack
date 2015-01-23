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

require 'fileutils'
require 'liberty_buildpack/diagnostics/common'
require 'liberty_buildpack/container/common_paths'
require 'liberty_buildpack/jre'
require 'liberty_buildpack/jre/memory/openjdk_memory_heuristic_factory'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/application_cache'
require 'liberty_buildpack/util/format_duration'
require 'pathname'

module LibertyBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class OpenJdk

    # Filename of killjava script used to kill the JVM on OOM.
    KILLJAVA_FILE_NAME = 'killjava.sh'

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties provided by the user
    # @option contect [String] :jvm_type the type of jvm the user wants to use e.g ibmjre or openjdk
    def initialize(context)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @java_opts = context[:java_opts]
      @configuration = context[:configuration]
      @common_paths = context[:common_paths] || LibertyBuildpack::Container::CommonPaths.new
      @jvm_type = context[:jvm_type]
      context[:java_home].concat JAVA_HOME unless context[:java_home].include? JAVA_HOME
    end

    # Detects which version of Java this application should use.  *NOTE:* This method will only return a value
    # if the jvm_type is set to openjdk.
    #
    # @return [String, nil] returns +ibmjdk-<version>+.
    def detect
      return nil if @jvm_type.nil? || !@jvm_type.downcase.start_with?('openjdk')
      @version = OpenJdk.find_openjdk(@configuration, @jvm_type)[0]
      id @version
    end

    # Downloads and unpacks a OpenJdk
    #
    # @return [void]
    def compile
      @version, @uri = OpenJdk.find_openjdk(@configuration, @jvm_type)
      download_start_time = Time.now

      print "-----> Downloading OpenJdk #{@version} from #{@uri} "

      LibertyBuildpack::Util::ApplicationCache.new.get(@uri) do |file|  # TODO: Use global cache
        puts "(#{(Time.now - download_start_time).duration})"
        expand file
      end
      copy_killjava_script
    end

    # Build Java memory options and places then in +context[:java_opts]+
    #
    # @return [void]
    def release
      @version = OpenJdk.find_openjdk(@configuration, @jvm_type)[0]
      user_version =  OpenJdk.user_requested_version(@configuration, @jvm_type)
      @java_opts << "-XX:OnOutOfMemoryError=#{@common_paths.diagnostics_directory}/#{KILLJAVA_FILE_NAME}"
      @java_opts.concat memory(user_version)
    end

    private

    RESOURCES = '../../../resources/openjdk/diagnostics'.freeze

    JAVA_HOME = '.java'.freeze

    KEY_MEMORY_HEURISTICS = 'memory_heuristics'

    KEY_MEMORY_SIZES = 'memory_sizes'
    KEY_REPOSITORY_ROOT = 'repository_root'.freeze
    KEY_VERSION = 'version'.freeze
    KEY_DEFAULT = 'default'.freeze

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding OpenJdk to #{JAVA_HOME} "

      FileUtils.rm_rf(java_home)
      FileUtils.mkdir_p(java_home)

      system "tar xzf #{file.path} -C #{java_home} --strip 1 2>&1"
      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_openjdk(configuration, jvm_type)
      version =  OpenJdk.user_requested_version(configuration, jvm_type)
      repository_configuration = { KEY_REPOSITORY_ROOT => configuration[KEY_REPOSITORY_ROOT], KEY_VERSION => version }
      LibertyBuildpack::Repository::ConfiguredItem.find_item(repository_configuration)
    rescue => e
      raise RuntimeError, "OpenJdk error: #{e.message}", e.backtrace
    end

    def id(version)
      "openjdk-#{version}"
    end

    def java_home
      File.join @app_dir, JAVA_HOME
    end

    def self.cache_dir(file)
      File.dirname(file.path)
    end

    def memory(version)
      sizes = @configuration[KEY_MEMORY_SIZES] ? @configuration[KEY_MEMORY_SIZES].clone : {}
      heuristics = @configuration[KEY_MEMORY_HEURISTICS] ? @configuration[KEY_MEMORY_HEURISTICS].clone : {}
      if version.start_with?('1.7')
        heuristics.delete 'metaspace'
        sizes.delete 'metaspace'
      else
        heuristics.delete 'permgen'
        sizes.delete 'permgen'
      end
      OpenJDKMemoryHeuristicFactory.create_memory_heuristic(sizes, heuristics, @version).resolve
    end

    def copy_killjava_script
      resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
      killjava_file_content = File.read(File.join resources, KILLJAVA_FILE_NAME)
      updated_content = killjava_file_content.gsub(/@@LOG_FILE_NAME@@/, LibertyBuildpack::Diagnostics::LOG_FILE_NAME)
      diagnostic_dir = LibertyBuildpack::Diagnostics.get_diagnostic_directory @app_dir
      FileUtils.mkdir_p diagnostic_dir
      File.open(File.join(diagnostic_dir, KILLJAVA_FILE_NAME), 'w', 0755) do |file|
        file.write updated_content
      end
    end

    # Determine the requested JVM version based on the value of the JVM environment variable (@jvm_type).
    #
    # @param [Hash] config the configuration hash from the context passed to this object in the context.
    # @param [String] jvm_type the contents of the JVM environment variable (passed in as the contexts @jvm_type attribute)
    def self.user_requested_version(config, jvm_type)
      return config[KEY_VERSION][config[KEY_VERSION][KEY_DEFAULT]] if jvm_type.nil?
      parts = jvm_type.split('-', 2)
      return config[KEY_VERSION][config[KEY_VERSION][KEY_DEFAULT]] if parts.empty? || parts.size == 1
      requested = parts[1]
      version = config[KEY_VERSION][requested]
      if version.nil?
        LibertyBuildpack::Diagnostics::LoggerFactory.get_logger.debug("No mapping found for requested jre version #{requested}, using the default")
        return config[KEY_VERSION][config[KEY_VERSION][KEY_DEFAULT]]
      end
      version
    end
  end

end

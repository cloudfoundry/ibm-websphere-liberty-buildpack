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
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/cache/application_cache'
require 'liberty_buildpack/util/format_duration'
require 'liberty_buildpack/util/tokenized_version'
require 'pathname'

module LibertyBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class OpenJdk

    # Filename of killjava script used to kill the JVM on OOM.
    KILLJAVA_FILE_NAME = 'killjava.sh'.freeze

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties provided by the user
    # @option contect [String] :jvm_type the type of jvm the user wants to use e.g ibmjre or openjdk
    def initialize(context)
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
      if !@jvm_type.nil? && 'openjdk'.casecmp(@jvm_type) == 0
        @version = OpenJdk.find_openjdk(@configuration)[0]
        id(@version)
      end
    end

    # Downloads and unpacks a OpenJdk
    #
    # @return [void]
    def compile
      @version, @uri = OpenJdk.find_openjdk(@configuration)
      download_start_time = Time.now

      print "-----> Downloading OpenJdk #{@version} from #{@uri} "

      LibertyBuildpack::Util::Cache::ApplicationCache.new.get(@uri) do |file| # TODO: Use global cache
        puts "(#{(Time.now - download_start_time).duration})"
        expand file
      end
      copy_killjava_script
    end

    # Build Java memory options and places then in +context[:java_opts]+
    #
    # @return [void]
    def release
      @version = OpenJdk.find_openjdk(@configuration)[0]
      @java_opts << "-XX:OnOutOfMemoryError=#{@common_paths.diagnostics_directory}/#{KILLJAVA_FILE_NAME}"
      memory
    end

    private

    RESOURCES = '../../../resources/openjdk/diagnostics'.freeze

    JAVA_HOME = '.java'.freeze

    KEY_MEMORY_HEURISTICS = 'memory_heuristics'.freeze

    KEY_MEMORY_SIZES = 'memory_sizes'.freeze

    VERSION_8 = LibertyBuildpack::Util::TokenizedVersion.new('1.8.0').freeze

    MEMORY_CONFIG_FOLDER = '.memory_config/'.freeze

    MEMORY_HEURISTICS_FILE = 'heuristics'.freeze

    MEMORY_SIZES_FILE = 'sizes'.freeze

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding OpenJdk to #{JAVA_HOME} "

      FileUtils.rm_rf(java_home)
      FileUtils.mkdir_p(java_home)

      system "tar xzf #{file.path} -C #{java_home} --strip 1 2>&1"

      if system("[ $(ls #{java_home} | wc -l) = 1 ]") && system("[ ! $(ls #{java_home} | grep -w 'jre') ]")
        FileUtils.rm_rf(java_home)
        FileUtils.mkdir_p(java_home)
        system "tar xzf #{file.path} -C #{java_home} --strip 2 2>&1"
      end

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_openjdk(configuration)
      LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration)
    rescue => e
      raise RuntimeError, "OpenJdk error: #{e.message}", e.backtrace
    end

    def id(version)
      "openjdk-#{version}"
    end

    def java_home
      File.join @app_dir, JAVA_HOME
    end

    def memory
      sizes      = @configuration[KEY_MEMORY_SIZES] ? @configuration[KEY_MEMORY_SIZES].clone : {}
      heuristics = @configuration[KEY_MEMORY_HEURISTICS] ? @configuration[KEY_MEMORY_HEURISTICS].clone : {}

      if @version < VERSION_8
        heuristics.delete 'metaspace'
        sizes.delete 'metaspace'
      else
        heuristics.delete 'permgen'
        sizes.delete 'permgen'
      end

      write_memory_config(heuristics, sizes)
    end

    def memory_heuristics_file
      File.join(@app_dir, MEMORY_CONFIG_FOLDER, MEMORY_HEURISTICS_FILE)
    end

    def memory_sizes_file
      File.join(@app_dir, MEMORY_CONFIG_FOLDER, MEMORY_SIZES_FILE)
    end

    def write_memory_config(heuristics, sizes)
      FileUtils.mkdir_p File.join(@app_dir, MEMORY_CONFIG_FOLDER)

      File.open(memory_heuristics_file, 'w') { |file| file.write(heuristics) }

      File.open(memory_sizes_file, 'w') { |file| file.write(sizes) }
    end

    def copy_killjava_script
      resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
      killjava_file_content = File.read(File.join(resources, KILLJAVA_FILE_NAME))
      updated_content = killjava_file_content.gsub(/@@LOG_FILE_NAME@@/, LibertyBuildpack::Diagnostics::LOG_FILE_NAME)
      diagnostic_dir = LibertyBuildpack::Diagnostics.get_diagnostic_directory @app_dir
      FileUtils.mkdir_p diagnostic_dir
      File.open(File.join(diagnostic_dir, KILLJAVA_FILE_NAME), 'w', 0o755) do |file|
        file.write updated_content
      end
    end

  end

end

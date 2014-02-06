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

require 'fileutils'
require 'liberty_buildpack/diagnostics/common'
require 'liberty_buildpack/jre'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/application_cache'
require 'liberty_buildpack/util/format_duration'
require 'liberty_buildpack/util/tokenized_version'
require 'liberty_buildpack/util/license_management'
require 'liberty_buildpack/jre/memory/memory_limit'
require 'liberty_buildpack/jre/memory/memory_size'
require 'pathname'

module LibertyBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class IBMJdk

    # Filename of killjava script used to kill the JVM on OOM.
    KILLJAVA_FILE_NAME = 'killjava'

    # The ratio of heap reservation to total reserved memory
    HEAP_SIZE_RATIO = 0.75

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @java_opts = context[:java_opts]
      @configuration = context[:configuration]
      @version, @uri, @license = IBMJdk.find_ibmjdk(@configuration)
      @license_id = context[:license_ids]['IBM_JVM_LICENSE']
      @jvm_type = context[:jvm_type]
      context[:java_home].concat JAVA_HOME unless context[:java_home].include? JAVA_HOME
    end

    # Detects which version of Java this application should use.  *NOTE:* This method will always return _some_ value,
    # so it should only be used once that application has already been established to be a Java application.
    #
    # @return [String, nil] returns +ibmjdk-<version>+.
    def detect
      id @version if @jvm_type == '' || @jvm_type == nil || 'ibmjre'.casecmp(@jvm_type) == 0
    end

    # Downloads and unpacks a JRE
    #
    # @return [void]
    def compile
      unless LibertyBuildpack::Util.check_license(@license, @license_id)
        print "\nYou have not accepted the IBM JVM License.\n\nVisit the following uri:\n#{@license}\n\nExtract the license number (D/N:) and place it inside your manifest file as a ENV property e.g. \nENV: \n  IBM_JVM_LICENSE: {License Number}.\n"
        raise
      end

      download_start_time = Time.now
      print "-----> Downloading IBM #{@version} JRE from #{@uri} "

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
      @java_opts << "-XX:OnOutOfMemoryError=./#{LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{KILLJAVA_FILE_NAME}"
      @java_opts.concat memory(@configuration)
    end

    private

    RESOURCES = '../../../resources/openjdk/diagnostics'.freeze

    JAVA_HOME = '.java'.freeze

    KEY_MEMORY_HEURISTICS = 'memory_heuristics'

    KEY_MEMORY_SIZES = 'memory_sizes'

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding JRE to #{JAVA_HOME} "

      system "rm -rf #{java_home}"
      system "mkdir -p #{java_home}"

      if File.basename(file.path).end_with?('.bin.cached', '.bin')
        cache_dir = IBMJdk.cache_dir(file)
        response_file = File.new(File.join(cache_dir, 'response.properties'), 'w')
        response_file.puts('INSTALLER_UI=silent')
        response_file.puts("USER_INSTALL_DIR=#{java_home}")
        response_file.close

        system "chmod +x #{file.path}"

        system "#{file.path} -i silent -f #{response_file.path} 2>&1"

        Pathname.new(cache_dir).children.select { |child| child.directory? }.map { |path| system "mv #{path.to_s}/* #{java_home}" }
      else
        system "tar xzf #{file.path} -C #{java_home} --strip 1 2>&1"
      end

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_ibmjdk(configuration)
      LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration)
    rescue => e
      raise RuntimeError, "IBM JRE error: #{e.message}", e.backtrace
    end

    def id(version)
      "ibmjdk-#{version}"
    end

    def java_home
      File.join @app_dir, JAVA_HOME
    end

    def self.cache_dir(file)
      File.dirname(file.path)
    end

    def memory(configuration)
      mem = MemoryLimit.memory_limit
      if mem.nil?
        ## if no memory option has been set by cloudfoundry, we just assume defaults
        ## except for no compressed refs.
        java_memory_opts = []
        java_memory_opts.push '-Xnocompressedrefs'
        java_memory_opts.push '-Xtune:virtualized'

        java_memory_opts
      else
        java_memory_opts = []

        if mem < MemorySize.new('512M')
          java_memory_opts.push '-Xnocompressedrefs'
        end

        new_heap_size = mem * HEAP_SIZE_RATIO

        java_memory_opts.push '-Xtune:virtualized'
        java_memory_opts.push "-Xmx#{new_heap_size}"

        java_memory_opts
      end
    end

    def pre_8
      @version < LibertyBuildpack::Util::TokenizedVersion.new('1.8.0')
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

  end

end

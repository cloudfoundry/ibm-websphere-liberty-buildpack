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
require 'liberty_buildpack/jre'
require 'liberty_buildpack/container/common_paths'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/cache/application_cache'
require 'liberty_buildpack/util/format_duration'
require 'liberty_buildpack/util/tokenized_version'
require 'liberty_buildpack/util/license_management'
require 'liberty_buildpack/jre/memory/memory_limit'
require 'liberty_buildpack/jre/memory/memory_size'
require 'pathname'
require 'tempfile'

module LibertyBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class IBMJdk

    # The ratio of heap reservation to total reserved memory
    HEAP_SIZE_RATIO = 0.75

    # Filename of killjava script used to kill the JVM on OOM.
    KILLJAVA_FILE_NAME = 'killjava.sh'.freeze

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [CommonPaths] :common_paths the set of paths common across components that components should reference
    # @option context [Hash] :license_ids the licenses accepted by the user
    # @option contect [String] :jvm_type the type of jvm the user wants to use e.g ibmjre or openjdk
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @java_opts = context[:java_opts]
      @common_paths = context[:common_paths] || LibertyBuildpack::Container::CommonPaths.new
      @configuration = context[:configuration]
      @license_id = context[:license_ids]['IBM_JVM_LICENSE']
      @jvm_type = context[:jvm_type]
      context[:java_home].concat JAVA_HOME unless context[:java_home].include? JAVA_HOME
    end

    # Detects which version of Java this application should use.  *NOTE:* This method will always return _some_ value,
    # so it should only be used once that application has already been established to be a Java application.
    #
    # @return [String, nil] returns +ibmjdk-<version>+.
    def detect
      @version = IBMJdk.find_ibmjdk(@configuration)[0]
      id @version if @jvm_type == '' || @jvm_type.nil? || 'ibmjre'.casecmp(@jvm_type) == 0
    end

    # Downloads and unpacks a JRE
    #
    # @return [void]
    def compile
      @version, @uri, @license = IBMJdk.find_ibmjdk(@configuration)
      unless LibertyBuildpack::Util.check_license(@license, @license_id)
        print "\nYou have not accepted the IBM JVM License.\n\nVisit the following uri:\n#{@license}\n\nExtract the license number (D/N:) and place it inside your manifest file as a ENV property e.g. \nENV: \n  IBM_JVM_LICENSE: {License Number}.\n"
        raise
      end

      # Checks that user has defined a sufficient memory limit
      check_memory

      download_start_time = Time.now
      if @uri.include? '://'
        print "-----> Downloading IBM #{@version} JRE from #{@uri} ... "
      else
        filename = File.basename(@uri)
        print "-----> Retrieving IBM #{@version} JRE (#{filename}) ... "
      end
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
      @java_opts.concat memory_opts
      @java_opts.concat tls_opts
      @java_opts.concat default_dump_opts
      @java_opts << '-Xshareclasses:none'
      @java_opts << "-Xdump:tool:events=systhrow,filter=java/lang/OutOfMemoryError,request=serial+exclusive,exec=#{@common_paths.diagnostics_directory}/#{KILLJAVA_FILE_NAME}"
    end

    # Prints a warning message if a memory limit of less than 512M has been chosen when using the IBM JDK.
    def check_memory
      mem_limit = MemoryLimit.memory_limit
      unless mem_limit.nil?
        if mem_limit < MemorySize.new('512M')
          puts '-----> Avoid Trouble: Specify a minimum of 512M as the Memory Limit for your apps when using IBM JDK.'
        end
      end
    end

    private

    RESOURCES = '../../../resources/ibmjdk/diagnostics'.freeze

    JAVA_HOME = '.java'.freeze

    VERSION_8 = LibertyBuildpack::Util::TokenizedVersion.new('1.8.0').freeze

    def expand(file)
      expand_start_time = Time.now
      print "         Expanding JRE to #{JAVA_HOME} ... "

      FileUtils.rm_rf(java_home)
      FileUtils.mkdir_p(java_home)

      if File.basename(file.path).end_with?('.bin.cached', '.bin')
        response_file = Tempfile.new('response.properties')
        response_file.puts('INSTALLER_UI=silent')
        response_file.puts('LICENSE_ACCEPTED=TRUE')
        response_file.puts("USER_INSTALL_DIR=#{java_home}")
        response_file.close

        File.chmod(0o755, file.path) unless File.executable?(file.path)
        system "#{file.path} -i silent -f #{response_file.path} 2>&1"
      else
        system "tar xzf #{file.path} -C #{java_home} --strip 1 2>&1"
      end

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_ibmjdk(configuration)
      version, entry = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration)
      if entry.is_a?(Hash)
        return version, entry['uri'], entry['license']
      else
        return version, entry, nil
      end
    rescue => e
      raise RuntimeError, "IBM JRE error: #{e.message}", e.backtrace
    end

    def id(version)
      "ibmjdk-#{version}"
    end

    def java_home
      File.join @app_dir, JAVA_HOME
    end

    def memory_opts
      java_memory_opts = []
      java_memory_opts.push '-Xtune:virtualized'

      mem = MemoryLimit.memory_limit
      if mem.nil?
        ## if no memory option has been set by cloudfoundry, we just assume defaults
      else
        new_heap_size = mem * heap_size_ratio
        java_memory_opts.push "-Xmx#{new_heap_size}"
      end
      java_memory_opts
    end

    def tls_opts
      opts = []
      # enable all TLS protocols when SSLContext.getInstance("TLS") is called
      opts << '-Dcom.ibm.jsse2.overrideDefaultTLS=true'
      if @version < VERSION_8
        # enable all TLS protocols when SSLContext.getDefault() is called
        opts << '-Dcom.ibm.jsse2.overrideDefaultProtocol=SSL_TLSv2'
      end
      opts
    end

    def heap_size_ratio
      @configuration['heap_size_ratio'] || HEAP_SIZE_RATIO
    end

    # default options for -Xdump to disable dumps while routing to the default dumps location when it is enabled by the
    # user
    def default_dump_opts
      default_options = []
      default_options.push '-Xdump:none'
      default_options.push "-Xdump:heap:defaults:file=#{@common_paths.dump_directory}/heapdump.%Y%m%d.%H%M%S.%pid.%seq.phd"
      default_options.push "-Xdump:java:defaults:file=#{@common_paths.dump_directory}/javacore.%Y%m%d.%H%M%S.%pid.%seq.txt"
      default_options.push "-Xdump:snap:defaults:file=#{@common_paths.dump_directory}/Snap.%Y%m%d.%H%M%S.%pid.%seq.trc"
      default_options.push '-Xdump:heap+java+snap:events=user'
      default_options
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

# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright IBM Corp. 2023
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
require 'liberty_buildpack/framework'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/cache/application_cache'
require 'pathname'
require 'tempfile'

module LibertyBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for selecting a ruby runtime.
  class Ruby

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
      @configuration = context[:configuration]
      @environment = context[:environment]
    end

    # Detects which version of Java this application should use.  *NOTE:* This method will always return _some_ value,
    # so it should only be used once that application has already been established to be a Java application.
    #
    # @return [String, nil] returns +ibmjdk-<version>+.
    def detect
	  File.exist?("/tmp/ruby")
    end

    # Downloads and unpacks a JRE
    #
    # @return [void]
    def compile
      @version, @uri = Ruby.find_ruby(@configuration)
	  @logger.debug { "version #{@version}" }
	  @logger.debug { "uri #{@uri}" }

      download_start_time = Time.now
      if @uri.include? '://'
        print "-----> Downloading #{@version} ruby from #{@uri} ... "
      else
        filename = File.basename(@uri)
        print "-----> Retrieving #{@version} ruby (#{filename}) ... "
      end
      LibertyBuildpack::Util::Cache::ApplicationCache.new.get(@uri) do |file| # TODO: Use global cache
        puts "(#{(Time.now - download_start_time).duration})"
        expand file
      end
    end

    # Build Java memory options and places then in +context[:java_opts]+
    #
    # @return [void]
    def release
	# need to set path
    end

    private

    RUBY_HOME = '.ruby'.freeze

    def expand(file)
      expand_start_time = Time.now
      print "         Expanding ruby to #{RUBY_HOME} ... "

      FileUtils.rm_rf(ruby_home)
      FileUtils.mkdir_p(ruby_home)

      system "tar xzf #{file.path} -C #{ruby_home} --strip 1 2>&1"

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_ruby(configuration)
      version, entry = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration)
      @logger.debug { "version #{version}" }
	  @logger.debug { "entry #{@entry}" }
      if entry.is_a?(Hash)
        return version, entry
      end
    rescue => e
      raise RuntimeError, "Ruby error: #{e.message}", e.backtrace
    end

    def ruby_home
      File.join @app_dir, RUBY_HOME
    end
  end
end

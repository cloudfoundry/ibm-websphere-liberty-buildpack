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

require 'liberty_buildpack/container/common_paths'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/format_duration'
require 'liberty_buildpack/util/tokenized_version'
require 'liberty_buildpack/util/cache/application_cache'

module LibertyBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class AdoptOpenJdk

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

    # Downloads and unpacks a OpenJdk
    #
    # @return [void]
    def install_jdk
      release = find_openjdk(@configuration)
      uri = release['binaries'][0]['binary_link']
      @version = release['release_name']
      download_start_time = Time.now

      print "-----> Downloading OpenJDK #{@version} from #{uri} "

      LibertyBuildpack::Util::Cache::ApplicationCache.new.get(uri) do |file| # TODO: Use global cache
        puts "(#{(Time.now - download_start_time).duration})"
        expand file
      end
    end

    private

    def java_home
      File.join @app_dir, JAVA_HOME
    end

    JAVA_HOME = '.java'.freeze

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding OpenJDK to #{JAVA_HOME} "

      FileUtils.rm_rf(java_home)
      FileUtils.mkdir_p(java_home)

      # AdoptOpenJDKs do not have jre/bin/java so that's ok
      depth = `tar tf #{file.path} | grep '/bin/java$' | grep -o / | wc -l`
      system "tar xzf #{file.path} -C #{java_home} --strip #{depth.to_i - 1} 2>&1"

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def find_openjdk(configuration)
      requested_version = LibertyBuildpack::Util::TokenizedVersion.new(configuration['version'])
      uri = openjdk_uri(requested_version, configuration['type'], configuration['heap_size'])
      cache.get(uri) do |file|
        releases = JSON.load(file)
        raise 'No OpenJDK versions found' if releases.length == 0

        candidates = {}
        releases.each do |release|
          binary_entry = release['binaries'][0]
          version_data = binary_entry['version_data']
          next if version_data.nil?

          sanitized_version = version_data['semver'].gsub(/\+.*$/, '')
          version = LibertyBuildpack::Util::TokenizedVersion.new(sanitized_version)
          candidates[version.to_s] = release
        end

        found_version = LibertyBuildpack::Repository::VersionResolver.resolve(requested_version, candidates.keys)
        raise "No version resolvable for '#{requested_version}' in #{candidates.keys.join(', ')}" if found_version.nil?
        found_release = candidates[found_version.to_s]
        return found_release
      end
    rescue => e
      raise RuntimeError, "OpenJDK error: #{e.message}", e.backtrace
    end

    def cache
      LibertyBuildpack::Util::Cache::DownloadCache.new(Pathname.new(Dir.tmpdir),
                                                       LibertyBuildpack::Util::Cache::CACHED_RESOURCES_DIRECTORY)
    end

    def openjdk_uri(version, type, heap_size)
      "https://api.adoptopenjdk.net/v2/info/releases/openjdk#{version[0]}?openjdk_impl=#{implementation}&type=#{type}&arch=x64&os=linux&heap_size=#{heap_size}"
    end

  end

end

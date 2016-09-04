# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013-2015 the original author or authors.
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

require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/repository'
require 'liberty_buildpack/repository/version_resolver'
require 'liberty_buildpack/repository/repository_utils'
require 'liberty_buildpack/util/cache'
require 'liberty_buildpack/util/cache/download_cache'
require 'liberty_buildpack/util/configuration_utils'
require 'rbconfig'
require 'yaml'

module LibertyBuildpack
  module Repository

    # A repository index represents the index of repository containing various versions of a file.
    class RepositoryIndex < RepositoryUtils

      # Creates a new repository index, populating it with values from an index file.
      #
      # @param [String] repository_root the root of the repository to create the index for
      def initialize(repository_root)
        super()

        cache.get("#{resolve_uri repository_root}#{INDEX_PATH}") do |file|
          @index = YAML.load_file(file)
          @logger.debug { @index }
        end
      end

      # Finds a version of the file matching the given, possibly wildcarded, version.
      #
      # @param [String] version the possibly wildcarded version to find
      # @return [TokenizedVersion] the version of the file found
      # @return [String] the URI of the file found
      def find_item(version)
        found_version = VersionResolver.resolve(version, @index.keys)
        raise "No version resolvable for '#{version}' in #{@index.keys.join(', ')}" if found_version.nil?
        uri = @index[found_version.to_s]
        [found_version, uri]
      end

      private

      INDEX_PATH = '/index.yml'.freeze

      private_constant :INDEX_PATH

      def cache
        LibertyBuildpack::Util::Cache::DownloadCache.new(Pathname.new(Dir.tmpdir),
                                                         LibertyBuildpack::Util::Cache::CACHED_RESOURCES_DIRECTORY)
      end

    end

  end
end

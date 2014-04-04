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

require 'liberty_buildpack/repository'
require 'liberty_buildpack/util/cache/download_cache'
require 'liberty_buildpack/repository/version_resolver'
require 'yaml'

module LibertyBuildpack::Repository

  # A repository index represents the index of repository containing various versions of a file.
  class RepositoryIndex

    # Creates a new repository index, populating it with values from an index file.
    #
    # @param [String] repository_root the root of the repository to create the index for
    def initialize(repository_root)
      @index = {}
      repository_root = repository_root[0..-2] while repository_root.end_with? '/'
      LibertyBuildpack::Util::Cache::DownloadCache.new.get("#{repository_root}#{INDEX_PATH}") do |file|
        @index.merge! YAML.load_file(file)
      end
    end

    # Finds a version of the file matching the given, possibly wildcarded, version.
    #
    # @param [String] version the possibly wildcarded version to find
    # @return [TokenizedVersion] the version of the file found
    # @return [String] the URI of the file found
    def find_item(version)
      version = VersionResolver.resolve(version, @index.keys)
      uri = @index[version.to_s]
      if @index[version.to_s].include?('uri') && @index[version.to_s].include?('license')
        uri = @index[version.to_s]['uri']
        license = @index[version.to_s]['license']
      end
      return version, uri, license # rubocop:disable RedundantReturn
    end

    private

      INDEX_PATH = '/index.yml'

  end

end

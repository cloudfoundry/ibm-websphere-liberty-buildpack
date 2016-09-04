# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
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
require 'yaml'

module LibertyBuildpack::Repository

  # A component index represents the index of available components of a given release in the repository.
  class ComponentIndex
    attr_reader :components # list of URI to the components of Liberty

    # Creates a new component index of component files for a given version.  The URI provided in the main repository
    # root's index will either be the URI to a tar of all the Liberty components or the URI to the component index file
    # if the components are split.
    #
    # Return the map of component name to URI if the components are split, and nil otherwise.
    #
    # @param [String] release_root_uri either the component index or a tar of all the components
    def initialize(release_root_uri)
      if !release_root_uri.nil? && release_root_uri.end_with?(COMP_INDEX_PATH.to_s)
        @comp_index = {}
        cache.get(release_root_uri.to_s) do |file|
          @comp_index.merge! YAML.load_file(file)
        end
        @components = @comp_index
      else
        @components = nil
      end
    end

    private

    COMP_INDEX_PATH = '/component_index.yml'.freeze

    def cache
      LibertyBuildpack::Util::Cache::DownloadCache.new(Pathname.new(Dir.tmpdir),
                                                       LibertyBuildpack::Util::Cache::CACHED_RESOURCES_DIRECTORY)
    end

  end

end

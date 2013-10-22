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
require 'liberty_buildpack/repository/repository_index'
require 'liberty_buildpack/util/tokenized_version'

module LibertyBuildpack::Repository

  # A class encapsulating details of a file stored in a versioned repository.
  class ConfiguredItem

    # Finds an instance of the file based on the configuration.
    #
    # @param [Hash] configuration the configuration
    # @option configuration [String] :repository_root the root directory of the repository
    # @option configuration [String] :version the version of the file to resolve
    # @param [Block, nil] version_validator an optional version validation block
    # @return [String] the URI of the chosen version of the file
    # @return [LibertyBuildpack::Util::TokenizedVersion] the chosen version of the file
    def self.find_item(configuration, &version_validator)
      repository_root = ConfiguredItem.repository_root(configuration)
      version = ConfiguredItem.version(configuration)
      version_validator.call(version) if version_validator
      index = ConfiguredItem.index(repository_root)
      index.find_item version
    end

    private

      KEY_REPOSITORY_ROOT = 'repository_root'.freeze

      KEY_VERSION = 'version'.freeze

      def self.index(repository_root)
        RepositoryIndex.new(repository_root)
      end

      def self.repository_root(configuration)
        raise "A repository root must be specified as a key-value pair of '#{KEY_REPOSITORY_ROOT}'' to the URI of the repository." unless configuration.has_key? KEY_REPOSITORY_ROOT
        configuration[KEY_REPOSITORY_ROOT]
      end

      def self.version(configuration)
        LibertyBuildpack::Util::TokenizedVersion.new(configuration[KEY_VERSION])
      end

  end

end

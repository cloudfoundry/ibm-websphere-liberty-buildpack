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
require 'liberty_buildpack/util/tokenized_version'

module LibertyBuildpack::Repository

  # A resolver that selects values from a collection based on a set of rules governing wildcards
  class VersionResolver

    # Resolves a version from a collection of versions.  The +candidate_version+ must be structured like:
    #   * up to three numeric components, followed by an optional string component
    #   * the final component may be a +
    # The resolution returns the maximum of the versions that match the candidate version
    #
    # @param [TokenizedVersion] candidate_version the version, possibly containing a wildcard, to resolve.  If +nil+,
    #                                        substituted with +.
    # @param [Array<String>] versions the collection of versions to resolve against
    # @return [TokenizedVersion] the resolved version
    # @raise if no version can be resolved
    def self.resolve(candidate_version, versions)
      tokenized_candidate_version = safe_candidate_version candidate_version
      tokenized_versions = versions.map { |version| LibertyBuildpack::Util::TokenizedVersion.new(version, false) }

      version = tokenized_versions
      .select { |tokenized_version| matches? tokenized_candidate_version, tokenized_version }
        .max { |a, b| a <=> b }

      raise "No version resolvable for '#{candidate_version}' in #{versions.join(', ')}" if version.nil?
      version
    end

    private

      TOKENIZED_WILDCARD = LibertyBuildpack::Util::TokenizedVersion.new('+')

      def self.safe_candidate_version(candidate_version)
        if candidate_version.nil?
          TOKENIZED_WILDCARD
        else
          raise "Invalid TokenizedVersion '#{candidate_version}'" unless candidate_version.is_a?(LibertyBuildpack::Util::TokenizedVersion)
          candidate_version
        end
      end

      def self.matches?(tokenized_candidate_version, tokenized_version)
        (0..3).all? do |i|
          tokenized_candidate_version[i].nil? ||
            tokenized_candidate_version[i] == LibertyBuildpack::Util::TokenizedVersion::WILDCARD ||
            tokenized_candidate_version[i] == tokenized_version[i]
        end
      end

  end

end

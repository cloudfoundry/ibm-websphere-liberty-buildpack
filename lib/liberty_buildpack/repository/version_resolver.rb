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

require 'liberty_buildpack/repository'
require 'liberty_buildpack/util/tokenized_version'
require 'liberty_buildpack/diagnostics/logger_factory'

module LibertyBuildpack
  module Repository

    # A resolver that selects values from a collection based on a set of rules governing wildcards
    class VersionResolver

      private_class_method :new

      class << self

        # Resolves a version from a collection of versions.  The +candidate_version+ must be structured like:
        #   * up to three numeric components, followed by an optional string component
        #   * the final component may be a +
        # The resolution returns the maximum of the versions that match the candidate version
        #
        # @param [TokenizedVersion] candidate_version the version, possibly containing a wildcard, to resolve.  If
        #                                             +nil+, substituted with +.
        # @param [Array<String>] versions the collection of versions to resolve against
        # @return [TokenizedVersion] the resolved version or nil if no matching version is found
        def resolve(candidate_version, versions)
          tokenized_candidate_version = safe_candidate_version candidate_version
          tokenized_versions          = versions.map { |version| create_token(version) }.compact

          # this is to test out the script.
          # if(tokenized_versions.last.to_s == "1.8.0_sr5")
          #    tokenized_versions.pop
          # end

          version = tokenized_versions
                    .select { |tokenized_version| matches? tokenized_candidate_version, tokenized_version }
                    .max { |a, b| version_compare(a, b) }
          version
        end

        # Compares two distinct versions using only the numbers
        # @param [String] a is one of the versions to compare
        # @param [String] b is the other version to compare
        # @return [Integer] 1, if a is greater than b; 0 if they are the same value; and -1 if a is less than b
        def version_compare(a, b)
          a.zip(b).each do |c, d|
            if !/\A\d+\z/.match(c)

              num_arr = clean_version_letters(c)

              num_arr2 = clean_version_letters(d)

              # Compare each number now from left to right

              num_arr.zip(num_arr2).each do |first, second|
                next unless (first.to_f <=> second.to_f) != 0
                return first.to_f <=> second.to_f
              end
            else
              c = '0.' + c if c[0] == '0' && c.length > 1 # verify if there are leading 0s in order to determine it's a decimal number and treat it as such

              d = '0.' + d if d[0] == '0' && d.length > 1

              next unless (c.to_f <=> d.to_f) != 0
              return c.to_f <=> d.to_f
            end

            return 0 # if it reaches this point, it means that both versions are the same one
          end
        end

        # eliminates non numerical characters from a version number and returns an array with all the numbers from left to right
        # @param [String] ver is the version number to clean up and replace the letters with spaces and numbers in order to have a number version format
        # @return [Array<String>] the version number in an array where each element was separated by a '.'
        def clean_version_letters(ver)
          # Eliminating the letters (except ifx) for the string num in order to facilitate comparison
          dup_ver = ver.dup
          if dup_ver.include? 'ifx'
            dup_ver = dup_ver.gsub!('ifx', '.5') # converts ifx to .5 to be able to compare as a number
          end
          dup_ver = dup_ver.gsub!(/[a-zA-Z]/, ' ') # replaces letters with blank spaces

          if dup_ver.include? '_'
            dup_ver = dup_ver.tr!('_', ' ') # in case there is an "_", replace with a blank space
          end

          dup_ver.split(' ') # split the string into an array using the blank spaces as the splitting point
        end

        private

        TOKENIZED_WILDCARD = LibertyBuildpack::Util::TokenizedVersion.new('+').freeze

        private_constant :TOKENIZED_WILDCARD

        def create_token(version)
          LibertyBuildpack::Util::TokenizedVersion.new(version, false)
        rescue StandardError => e
          logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
          logger.warn { "Discarding illegal version #{version}: #{e.message}" }
          nil
        end

        def safe_candidate_version(candidate_version)
          if candidate_version.nil?
            TOKENIZED_WILDCARD
          else
            unless candidate_version.is_a?(LibertyBuildpack::Util::TokenizedVersion)
              raise "Invalid TokenizedVersion '#{candidate_version}'"
            end

            candidate_version
          end
        end

        def matches?(tokenized_candidate_version, tokenized_version)
          (0..3).all? do |i|
            tokenized_candidate_version[i].nil? ||
              tokenized_candidate_version[i] == LibertyBuildpack::Util::TokenizedVersion::WILDCARD ||
              tokenized_candidate_version[i] == tokenized_version[i]
          end
        end

      end

    end

  end
end

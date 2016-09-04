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

require 'liberty_buildpack/util'

module LibertyBuildpack::Util

  # A utility for manipulating JRE version numbers.
  class TokenizedVersion < Array
    include Comparable

    # The wildcard component.
    WILDCARD = '+'.freeze

    # Create a tokenized version based on the input string.
    #
    # @param [String] version a version string
    # @param [Boolean] allow_wildcards whether or not to allow '+' as the last component to represent a wildcard
    def initialize(version, allow_wildcards = true)
      @version = version
      @version = WILDCARD if !@version && allow_wildcards

      major, tail = major_or_minor_and_tail @version
      minor, tail = major_or_minor_and_tail tail
      micro, qualifier = micro_and_qualifier tail

      concat [major, minor, micro, qualifier]
      validate allow_wildcards
    end

    # Compare this to another array
    #
    # @return [Integer] A numerical representation of the comparison between two instances
    def <=>(other)
      comparison = 0
      i = 0
      while comparison == 0 && i < 3
        comparison = self[i].to_i <=> other[i].to_i
        i += 1
      end
      comparison = qualifier_compare(non_nil_qualifier(self[3]), non_nil_qualifier(other[3])) if comparison == 0

      comparison
    end

    # Convert this to a string
    #
    # @return [String] a string representation of this tokenized version
    def to_s
      @version
    end

    private

    COLLATING_SEQUENCE = ['-', '.'] + ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

    def char_compare(c1, c2)
      COLLATING_SEQUENCE.index(c1) <=> COLLATING_SEQUENCE.index(c2)
    end

    def major_or_minor_and_tail(s)
      if s.nil? || s.empty?
        major_or_minor = nil
        tail = nil
      else
        raise "Invalid version '#{s}': must not end in '.'" if s[-1] == '.'
        raise "Invalid version '#{s}': missing component" if s =~ /\.[\._]/
        tokens = s.match(/^([^\.]+)(?:\.(.*))?/)

        major_or_minor, tail = tokens[1..-1]

        raise "Invalid major or minor version '#{major_or_minor}'" unless valid_major_minor_or_micro major_or_minor
      end

      return major_or_minor, tail # rubocop:disable RedundantReturn
    end

    def micro_and_qualifier(s)
      if s.nil? || s.empty?
        micro = nil
        qualifier = nil
      else
        raise "Invalid version '#{s}': must not end in '_'" if s[-1] == '_'
        tokens = s.match(/^([^\_]+)(?:_(.*))?/)

        micro, qualifier = tokens[1..-1]

        raise "Invalid micro version '#{micro}'" unless valid_major_minor_or_micro micro
        raise "Invalid qualifier '#{qualifier}'" unless valid_qualifier qualifier
      end

      return micro, qualifier # rubocop:disable RedundantReturn
    end

    def minimum_qualifier_length(a, b)
      [a.length, b.length].min
    end

    def qualifier_compare(a, b)
      comparison = 0

      i = 0
      until comparison != 0 || i == minimum_qualifier_length(a, b)
        comparison = char_compare(a[i], b[i])
        i += 1
      end

      comparison = a.length <=> b.length if comparison == 0

      comparison
    end

    def non_nil_qualifier(qualifier)
      qualifier.nil? ? '' : qualifier
    end

    def validate(allow_wildcards)
      wildcarded = false
      each do |value|
        raise "Invalid version '#{@version}': wildcards are not allowed this context" if value == WILDCARD && !allow_wildcards

        raise "Invalid version '#{@version}': no characters are allowed after a wildcard" if wildcarded && !value.nil?
        wildcarded = true if value == WILDCARD
      end
      raise "Invalid version '#{@version}': missing component" if !wildcarded && compact.length < 3
    end

    def valid_major_minor_or_micro(major_minor_or_micro)
      major_minor_or_micro =~ /^[\d]*$/ || major_minor_or_micro =~ /^\+$/
    end

    def valid_qualifier(qualifier)
      qualifier.nil? || qualifier.empty? || qualifier =~ /^[-\.a-zA-Z\d]*$/ || qualifier =~ /^\+$/
    end
  end

end

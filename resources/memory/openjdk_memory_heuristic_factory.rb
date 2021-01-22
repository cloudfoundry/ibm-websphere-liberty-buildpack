# frozen_string_literal: true

# IBM WebSphere Application Server Liberty Buildpack
# Copyright IBM Corp. 2017
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

require_relative 'weight_balancing_memory_heuristic'

# A MemoryBucket is used to calculate default sizes for various type of memory
class OpenJDKMemoryHeuristicFactory

  private_class_method :new

  class << self

    # Returns a memory heuristics instance for the given version of OpenJDK.
    #
    # @param [Hash<String, String>] sizes any sizes specified by the user
    # @param [Hash<String, Numeric>] heuristics the memory heuristics specified by the user
    # @param [LibertyBuildpack::Util::TokenizedVersion] version the version of OpenJDK
    # @return [WeightBalancingMemoryHeuristic] the memory heuristics instance
    def create_memory_heuristic(sizes, heuristics, version)
      extra = permgen_or_metaspace(version)
      WeightBalancingMemoryHeuristic.new(sizes, heuristics, VALID_TYPES.dup << extra, JAVA_OPTS)
    end

    private

    VALID_TYPES = %w[heap stack native].freeze

    JAVA_OPTS = {
      'heap' => ->(v) { %W[-Xmx#{v} -Xms#{v}] },
      'metaspace' => ->(v) { %W[-XX:MaxMetaspaceSize=#{v} -XX:MetaspaceSize=#{v}] },
      'permgen' => ->(v) { %W[-XX:MaxPermSize=#{v} -XX:PermSize=#{v}] },
      'stack' => ->(v) { ["-Xss#{v}"] }
    }.freeze

    def permgen_or_metaspace(version)
      if version == '1.8.0'
        'metaspace'
      else
        'permgen'
      end
    end

  end

end

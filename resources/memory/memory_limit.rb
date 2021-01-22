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

require_relative 'memory_size'

# A utility for handling Java memory settings.
class MemoryLimit

  private_class_method :new

  class << self

    # Returns the application's memory limit.
    #
    # @return [MemorySize, nil] the application's memory limit or nil if no memory limit has been provided
    def memory_limit
      memory_limit = ENV['MEMORY_LIMIT']
      return nil unless memory_limit

      memory_limit_size = MemorySize.new(memory_limit)
      raise "Invalid negative $MEMORY_LIMIT #{memory_limit}" if memory_limit_size < 0

      memory_limit_size
    end

  end

end

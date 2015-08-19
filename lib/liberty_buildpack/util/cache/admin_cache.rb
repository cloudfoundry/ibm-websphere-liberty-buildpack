# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014-2015 the original author or authors.
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

require 'pathname'
require 'liberty_buildpack/util/cache'

module LibertyBuildpack::Util::Cache

  # A read-only collection of files packaged together with the buildpack.
  # The collection is referred to as 'admin cache' since it is used when
  # a buildpack is packaged to be installed as an admin buildpack and should
  # include binaries not available via network.
  class AdminCache

    # Location of the admin cache relative to the directory this file is in
    ADMIN_CACHE = Pathname.new(File.expand_path('../../../../admin_cache', File.dirname(__FILE__))).freeze

    # Yields an open file containing the cached data.
    #
    # @param [String] uri a uri which uniquely identifies the file in the cache root
    # @return [Boolean] +true+ if and only if data is cached
    def self.in_cache?(uri, &block)
      cached_file = CachedFile.new ADMIN_CACHE, uri, false
      if cached_file.cached?
        cached_file.cached(File::RDONLY | File::BINARY, false, &block)
        true
      else
        false
      end
    end

  end
end

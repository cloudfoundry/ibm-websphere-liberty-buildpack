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

require 'liberty_buildpack/util/heroku'

module LibertyBuildpack::Container

  # Representation of the common paths made available to the buildpack components. The relative_location should be
  # updated when the execution path occurs in a path other than the default working directory so that components do
  # not have to calculate the location of paths that are shared.
  class CommonPaths
    include LibertyBuildpack::Util

    attr_accessor :relative_location

    # The default execution location is at the root of the current working directory.  Containers that execute
    # in a different directory should update the relative_location.
    def initialize
       @relative_location = DEFAULT_LOCATION
    end

    # The relative location that should be updated when the execution path occurs in the non-default working directory
    #
    # @param new_relative_location new relative_location value
    def relative_location=(new_relative_location)
       if new_relative_location.nil? || new_relative_location.empty? || (new_relative_location.include? ' ')
          raise 'relative_location provided to common_paths must have a valid path value'
       end
       @relative_location = new_relative_location
    end

    # The expected log directory that components should store logs to.
    #
    # @return [String] the path of the log directory that components should route log files to
    def log_directory
       File.join(@relative_location, LOG_DIRECTORY_NAME)
    end

    # The expected dump directory that components should store dumps to.
    #
    # @return [String] the path of the dump directory that components should route dump files to
    def dump_directory
       File.join(@relative_location, DUMP_DIRECTORY_NAME)
    end

    # The buildpack's diagnostics directory which contains diagnostic scripts and logs that components may
    # reference.  The buildpack's returned diagnostics directory will be at the root of the droplet 'app' subdiectory,
    # if 'app' exists.  When the 'app' dir does not exist, the buildpack's diagnostic directory will be at
    # the root of the droplet.
    #
    # @return [String] path of the buildpack diagnostics directory
    def diagnostics_directory
       diag_location = @relative_location

       # Heroku does not have an 'app' directory
       unless Heroku.heroku?
         diag_location = File.join(@relative_location, 'app')
       end

       File.join(diag_location, DIAGNOSTICS_DIRECTORY_NAME)
    end

    private

    DEFAULT_LOCATION = '.'.freeze
    DIAGNOSTICS_DIRECTORY_NAME = LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY.freeze
    LOG_DIRECTORY_NAME = 'logs'.freeze
    DUMP_DIRECTORY_NAME = 'dumps'.freeze

  end

end

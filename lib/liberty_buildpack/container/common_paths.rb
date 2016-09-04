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

  # CommonPaths provides buildpack components with relative paths to centralize the paths needed by components. The
  # paths made available to the components are symbolic relative paths and are adjusted to handle path differences
  # that occur as a result of differences in the platform container or the runtime container.
  #
  # Platform differences exist for an application's exeuction directory. CFv2 environments execute applications in an
  # app root that has a the platform user directory as the parent directory.  The platform user directory may
  # contain other data such as logs. While Heroku has a platform user directory that is used as the application
  # directory.
  #
  # Container differences exist when a container's execution path isn't at the root of the application directory.
  #
  # Platform differences will automatically be adjusted based on the environment (and can be customized during
  # initialization) while container differences will be adjusted if the container has set Commonpaths.relative_location.
  class CommonPaths
    include LibertyBuildpack::Util

    # set by the container if needed
    attr_accessor :relative_location

    # CommonPaths will account for CFv2 having an 'app' directory as the application's root directory while Heroku's
    # application root directory will be the platform user directory.  The application  root directory will be adjusted
    # based on the environment and can be overwritten by providing an application root directory during initialization.
    #
    # @param [String] app_dir  a relative path to the application's home directory
    def initialize(app_dir = nil)
      # relative to the application's root dir
      @relative_location = CURRENT_DIR

      # set the default app's root directory according to the environment unless an application root is provided
      unless app_dir
        if !Heroku.heroku?
          app_dir = 'app'.freeze
        else
          app_dir = CURRENT_DIR
        end
      end

      # for recalculating the relative location of the execution dir to the base home directory
      # which may not necessarily be the same as the app root dir
      @relative_app_string = valid_relative_string(app_dir)

      update_relative_to_base
    end

    # The relative location that should be updated when the execution path occurs in the non-default working directory
    # as determined by the container component. Setting the relative_location with this method will convert the
    # provided relative path into one represented by symbols only.  Eg: Passing 'container/bin' will result in
    # '../..' as the relative_location.
    #
    # @param [String] new_relative_location the new_relative_location
    def relative_location=(new_relative_location)
      # Updates the application path according to the platform based on the given environment.  Heroku does not
      # append 'app' while CloudFoundry v2 appends 'app' as the application's root in an execution environment.
      # This allows us to adjust the common directories accordingly.
      @relative_location = valid_relative_string(new_relative_location)
      update_relative_to_base
    end

    # The expected log directory that components should store logs to.
    #
    # @return [String] the path of the log directory that components should route log files to
    def log_directory
      File.join(@relative_to_base, LOG_DIRECTORY_NAME)
    end

    # The expected dump directory that components should store dumps to.
    #
    # @return [String] the path of the dump directory that components should route dump files to
    def dump_directory
      File.join(@relative_to_base, DUMP_DIRECTORY_NAME)
    end

    # The buildpack's diagnostics directory which contains diagnostic scripts and logs that components may
    # reference.  The buildpack's returned diagnostics directory will be at the root of the droplet 'app' subdiectory,
    # if 'app' exists.  When the 'app' dir does not exist, the buildpack's diagnostic directory will be at
    # the root of the droplet.
    #
    # @return [String] path of the buildpack diagnostics directory
    def diagnostics_directory
      File.join(@relative_location, DIAGNOSTICS_DIRECTORY_NAME)
    end

    private

    def update_relative_to_base
      if @relative_app_string
        @relative_to_base = File.join(@relative_location, @relative_app_string)
      else
        @relative_to_base = @relative_location
      end
    end

    # Validates if a pathname is valid and considred relative.  When valid, the pathname will be converted to its
    # symbolic representation of a relative path. Ex: a relative_pathname of ./something/dir will return ../..
    def valid_relative_string(relative_pathname)
      if relative_pathname.nil? || relative_pathname.empty? || (relative_pathname.include? ' ')
        raise 'relative_location provided to common_paths must be nonempty and without spaces'
      end

      begin
        Pathname.new(CURRENT_DIR).relative_path_from(Pathname.new(relative_pathname)).to_s unless relative_pathname.eql? CURRENT_DIR
      rescue
        raise 'paths provided to CommonPaths must be a relative, subdirectory, and a valid Pathname'
      end
    end

    CURRENT_DIR = '.'.freeze
    DIAGNOSTICS_DIRECTORY_NAME = LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY.freeze
    LOG_DIRECTORY_NAME = 'logs'.freeze
    DUMP_DIRECTORY_NAME = 'dumps'.freeze

  end

end

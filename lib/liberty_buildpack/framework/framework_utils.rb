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

require 'fileutils'
require 'liberty_buildpack/container/liberty'
require 'liberty_buildpack/container/container_utils'
require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/framework'

module LibertyBuildpack::Framework

  # Utility methods for frameworks
  class FrameworkUtils

    # Find matches to the provided pattern in the given directory
    # @param [String] app_dir the directory structure in which we look for the pattern
    # @param [String] pattern the pattern that needs to be satisfied
    # @return [Array] applications within that directory that match the pattern
    def self.find(app_dir, pattern = ["#{app_dir}/**/*war", "#{app_dir}/**/*.ear"])
      apps = []
      matches = Dir.glob(pattern)
      matches.each do |path|
        ['.ear', '.war', "\/WEB-INF", 'lib'].each do |app_type|
          next unless path.include? app_type
          if app_type == '.ear' || app_type == '.war'
            match = path.scan(/.*\w+#{Regexp.quote(app_type)}/)
            apps.concat(match)
          elsif app_type == "\/WEB-INF"
            match = path.scan(/.*\w+#{Regexp.quote(app_type)}/)
            match = match.length > 0 ? [match[0].gsub('/WEB-INF', '')] : [app_dir]
            apps.concat(match)
          else
            match = path.scan(%r{^(.*)\/.*\w+\/})
            # capturing group value is array itself
            apps.concat(match[0])
          end
          break
        end
      end
      apps
    end

    # Find matches to the provided pattern in the given directory that aren't within applications
    # this search is only applicable for server pushes (packaged or exploded)
    # @param [String] app_dir the directory structure in which we look for the pattern
    # @param [String] pattern the pattern that needs to be satisfied
    # @return [Array] applications within that directory that match the pattern
    def self.find_shared_libs(app_dir, pattern)
      libs = []
      matches = Dir[pattern]
      matches.each do |path|
        libs << path if !path.include?('.ear') && !path.include?('.war')
      end
      libs
    end

    # creates a lib directory in the appropriate location for the application
    # @param [String] start_dir the root directory of the application
    def self.create_lib_dir(start_dir)
      if Liberty.web_inf(start_dir)
        FileUtils.mkdir_p(File.join(start_dir, 'WEB_INF', 'lib'))
      elsif Liberty.meta_inf(start_dir)
        FileUtils.mkdir_p(File.join(start_dir, 'lib'))
      end
    end

    # Links the framework libraries to the library directory of the application
    # @param [Array] apps the applications to link to
    # @param [String] lib_dir the path to the framework library directory
    def self.link_libs(apps, lib_dir)
      apps.each do |app_dir|
        libs = LibertyBuildpack::Container::ContainerUtils.libs(app_dir, lib_dir)
        next unless libs
        if LibertyBuildpack::Container::Liberty.web_inf(app_dir)
          app_web_inf_lib = web_inf_lib(app_dir)
          FileUtils.mkdir_p(app_web_inf_lib) unless File.exist?(app_web_inf_lib)
          app_web_inf_lib_path = Pathname.new(app_web_inf_lib)
          Pathname.glob(File.join(lib_dir, '*.jar')) do |jar|
            FileUtils.ln_sf(jar.relative_path_from(app_web_inf_lib_path), app_web_inf_lib)
          end
        elsif LibertyBuildpack::Container::Liberty.meta_inf(app_dir)
          app_ear_lib = ear_lib(app_dir)
          ear_lib_path = Pathname.new(app_ear_lib)
          FileUtils.mkdir_p(app_ear_lib) unless File.exist?(app_ear_lib)
          Pathname.glob(File.join(lib_dir, '*.jar')) do |jar|
            FileUtils.ln_sf(jar.relative_path_from(ear_lib_path), app_ear_lib)
          end
        end
      end
    end

    # creates a path to the library in a WAR
    # @param [String] app_dir the path to the application
    # @return the path to WEB-INF/lib
    def self.web_inf_lib(app_dir)
      File.join app_dir, 'WEB-INF', 'lib'
    end

    # creates a path to the library in a EAR
    # @param [String] app_dir the path to the application
    # @return the path to app.ear/lib
    def self.ear_lib(app_dir)
      File.join app_dir, 'lib'
    end

  end

end

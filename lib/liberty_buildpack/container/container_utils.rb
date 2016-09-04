# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013-2014 the original author or authors.
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

require 'liberty_buildpack/container'
require 'pathname'

module LibertyBuildpack::Container

  # Utilities common to container components
  class ContainerUtils

    # Converts an +Array+ of Java options to a +String+ suitable for use on a BASH command line
    #
    # @param [Array<String>] java_opts the array of Java options
    # @return [String] the options formatted as a string suitable for use on a BASH command line
    def self.to_java_opts_s(java_opts)
      java_opts.compact.sort.join(' ')
    end

    # Evaluates a value and if it is not +nil+ or empty, prepends it with a space.  This can be used to create BASH
    # command lines that do not have ugly extra spacing.
    #
    # @param [String, nil] value the value to evalutate for extra spacing
    # @return [String] an empty string if +value+ is +nil+ or empty, otherwise the value prepended with a space
    def self.space(value)
      value.nil? || value.empty? ? '' : " #{value}"
    end

    # Returns an +Array+ containing the relative paths of the JARs located in the additional libraries directory.  The
    # paths of these JARs are relative to the +app_dir+.
    #
    # @param [String] app_dir the directory that the application exists in
    # @param [String] lib_directory the directory that additional libraries are placed in
    # @return [Array<String>] the relative paths of the JARs located in the additional libraries directory
    def self.libs(app_dir, lib_directory)
      libs = []
      if lib_directory
        root_directory = Pathname.new(app_dir)
        libs = Pathname.new(lib_directory).children
                       .select { |file| file.extname == '.jar' }
                       .map { |file| file.relative_path_from(root_directory) }
                       .sort
      end
      libs
    end

    # Unpacks the given zip file to the specified directory. It uses the +unzip+ or +jar+ command depending
    # of the runtime environment.
    #
    # @param [String] file - the zip file to unpack
    # @param [String] dir - the directory to unpack the zip contents into.
    # @return [void]
    def self.unzip(file, dir)
      file = File.expand_path(file)
      FileUtils.mkdir_p dir
      Dir.chdir(dir) do
        if File.exist? '/usr/bin/unzip'
          system "unzip -qqo '#{file}'"
        else
          system "jar xf \"#{file}\""
        end
      end
    end

    # Zips up a specified directory. It uses the +zip+ or +jar+ command depending of the runtime environment.
    #
    # @param [String] dir - the directory to zip up.
    # @param [String] file - the zip file to create.
    # @return [void]
    def self.zip(dir, file)
      file = File.expand_path(file)
      Dir.chdir(dir) do
        if File.exist? '/usr/bin/zip'
          system "zip -rq '#{file}' *"
        else
          system "jar cf \"#{file}\" *"
        end
      end
    end

    # Overlay JVM files. Move base_dir/resources/.java-overlay/.java files to app_dir/.
    #
    # @param [String] base_dir the base directory that contains Java files to overlay.
    # @param [String] app_dir the application directory where the files will be copied to.
    def self.overlay_java(base_dir, app_dir)
      java_overlay_dir = File.join(base_dir, RESOURCES_DIR, JAVA_OVERLAY_DIR)
      overlay_src = File.join(java_overlay_dir, JAVA_DIR)
      if Dir.exist?(overlay_src)
        print "-----> Overlaying Java files from #{overlay_src}\n"
        FileUtils.cp_r(overlay_src, app_dir)
        FileUtils.rm_rf(java_overlay_dir)
      end
    end

    RESOURCES_DIR = 'resources'.freeze

    JAVA_OVERLAY_DIR = '.java-overlay'.freeze

    JAVA_DIR = '.java'.freeze

    private_constant :RESOURCES_DIR, :JAVA_OVERLAY_DIR, :JAVA_DIR

  end
end

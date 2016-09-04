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
require 'liberty_buildpack/container'
require 'liberty_buildpack/util/dash_case'
require 'liberty_buildpack/util/java_main_utils'
require 'liberty_buildpack/util'
require 'liberty_buildpack/container/container_utils'

module LibertyBuildpack::Container
  # Encapsulates the detect, compile, and release functionality for dist_zip applications.
  class DistZip

    include LibertyBuildpack::Util

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
      @common_paths = context[:common_paths] || LibertyBuildpack::Container::CommonPaths.new
      @configuration = context[:configuration]
      @lib_directory = context[:lib_directory]
    end

    # If the component should be used when staging an application
    #
    # @return [Array<String>, String, nil] If the component should be used when staging the application, a +String+ or
    #                                      an +Array<String>+ that uniquely identifies the component (e.g.
    #                                      +open_jdk=1.7.0_40+).  Otherwise, +nil+.
    def detect
      supports? ? id : nil
    end

    # Modifies the application's file system.  The component is expected to transform the application's file system in
    # whatever way is necessary (e.g. downloading files or creating symbolic links) to support the function of the
    # component.  Status output written to +STDOUT+ is expected as part of this invocation.
    #
    # @return [Void]
    def compile
      File.chmod(0o755, start_script(root))
      augment_classpath_content
    end

    # Modifies the application's runtime configuration. The component is expected to transform members of the
    # +context+ # (e.g. +@java_home+, +@java_opts+, etc.) in whatever way is necessary to support the function of the
    # component.
    #
    # Container components are also expected to create the command required to run the application.  These components
    # are expected to read the +context+ values and take them into account when creating the command.
    #
    # @return [void, String] components other than containers are not expected to return any value.  Container
    #                        components are expected to return the command required to run the application.
    def release
      java_opts = @java_opts.nil? || @java_opts.empty? ? nil : @java_opts
      [
        "JAVA_HOME=#{check_jre_path}",
        'SERVER_PORT=$PORT',
        as_env_var(java_opts),
        qualify_path(start_script(root), @app_dir)
      ].flatten.compact.join(' ')
    end

    protected

    # The id of this container
    #
    # @return [String] the id of this container
    def id
      DistZip.to_s.dash_case
    end

    # The root directory of the application
    #
    # @return [Pathname] the root directory of the application
    def root
      find_single_directory || @app_dir
    end

    def supports?
      start_script(root) &&
      File.exist?(start_script(root)) &&
        jars?
    end

    def jars?
      Dir.glob(File.join(lib_dir, '*.jar')).any?
    end

    # The lib directory of the application
    #
    # @return [Pathname] the lib directory of the application
    def lib_dir
      File.join(root, 'lib')
    end

    # Find a start script relative to a root directory.  A start script is defined as existing in the +bin/+ directory
    # and being either the only file, or the only file with a counterpart named +<filename>.bat+
    #
    # @param [Pathname] root the root to search from
    # @return [Pathname, nil] the start script or +nil+ if one does not exist
    def start_script(root)
      return nil unless root
      candidates = Dir.glob(File.join(root, 'bin/*'))
      if candidates.size == 1
        candidates.first
      else
        Dir.glob(File.join(root, 'bin'))
        candidates.find { |candidate| Pathname.new("#{candidate}.bat").exist? }
      end
    end

    private

    PATTERN_APP_CLASSPATH = /^declare -r app_classpath=\"(.*)\"$/

    PATTERN_CLASSPATH = /^CLASSPATH=(.*)$/

    # private_constant :PATTERN_APP_CLASSPATH, :PATTERN_CLASSPATH

    def augment_app_classpath(content)
      additional_classpath = Dir.glob(@lib_directory + '/*').sort.map do |additional_library|
        "$app_home/#{Pathname.new(additional_library).relative_path_from(Pathname.new(root))}"
      end

      update_file start_script(root), content, PATTERN_APP_CLASSPATH, "declare -r app_classpath=\"#{additional_classpath.join(':')}:\\1\""
    end

    def augment_classpath(content)
      additional_classpath = Dir.glob(@lib_directory + '/*').sort.map do |additional_library|
        "$APP_HOME/#{Pathname.new(additional_library).relative_path_from(Pathname.new(root))}"
      end

      update_file start_script(root), content,
                  PATTERN_CLASSPATH, "CLASSPATH=#{additional_classpath.join(':')}:\\1"
    end

    def augment_classpath_content
      content = File.read(start_script(root))
      if content =~ PATTERN_CLASSPATH
        augment_classpath content
      elsif content =~ PATTERN_APP_CLASSPATH
        augment_app_classpath content
      end
    end

    def update_file(path, content, pattern, replacement)
      Pathname.new(path).open('w') do |f|
        f.write content.gsub pattern, replacement
        f.fsync
      end
    end

    # Find the single directory in the root of the droplet
    #
    # @return [Pathname, nil] the single directory in the root of the droplet, otherwise +nil+
    def find_single_directory
      roots = Dir.glob(File.join(@app_dir, '*')).select { |f| File.directory? f }
      roots.size == 1 ? roots.first : nil
    end

    # Qualifies the path such that is is formatted as +$PWD/<path>+.  Also ensures that the path is relative to a root,
    # which defaults to the +@droplet_root+ of the class.
    #
    # @param [Pathname] path the path to qualify
    # @param [Pathname] root the root to make relative to
    # @return [String] the qualified path
    def qualify_path(path, root = @app_dir)
      "$PWD/#{Pathname.new(path).relative_path_from(Pathname.new(root))}"
    end

    def java_home
      File.join('$PWD', @java_home)
    end

    def check_jre_path
      if File.exist?(File.join(@app_dir, @java_home, 'jre'))
        File.join(java_home, 'jre')
      else
        java_home
      end
    end

    def as_env_var(java_opts)
      "JAVA_OPTS=\"#{java_opts.join(' ')}\"" unless java_opts.nil?
    end
  end
end

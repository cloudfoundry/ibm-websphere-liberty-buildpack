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

require 'liberty_buildpack/jre/adopt_openjdk'

module LibertyBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class OpenJ9 < AdoptOpenJdk

    # The ratio of heap reservation to total reserved memory
    HEAP_SIZE_RATIO = 0.75

    # Filename of killjava script used to kill the JVM on OOM.
    KILLJAVA_FILE_NAME = 'killjava.sh'.freeze

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [CommonPaths] :common_paths the set of paths common across components that components should reference
    # @option context [Hash] :license_ids the licenses accepted by the user
    # @option contect [String] :jvm_type the type of jvm the user wants to use e.g ibmjre or openjdk
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      super(context)
    end

    # Detects which version of Java this application should use.  *NOTE:* This method will only return a value
    # if the jvm_type is set to openjdk.
    #
    # @return [String, nil] returns +openj9-<version>+.
    def detect
      if !@jvm_type.nil? && 'openj9'.casecmp(@jvm_type) == 0
        release = find_openjdk(@configuration)
        id(release['release_name'])
      end
    end

    # Downloads and unpacks a JRE
    #
    # @return [void]
    def compile
      install_jdk
      copy_killjava_script
      write_heap_size_ratio_file
    end

    # Build Java memory options and places then in +context[:java_opts]+
    #
    # @return [void]
    def release
      @java_opts.concat memory_opts
      @java_opts.concat default_dump_opts
      @java_opts << '-Xshareclasses:none'
      @java_opts << "-Xdump:tool:events=systhrow,filter=java/lang/OutOfMemoryError,request=serial+exclusive,exec=#{@common_paths.diagnostics_directory}/#{KILLJAVA_FILE_NAME}"
    end

    private

    RESOURCES = '../../../resources/ibmjdk/diagnostics'.freeze

    MEMORY_CONFIG_FOLDER = '.memory_config/'.freeze

    HEAP_RATIO_FILE = 'heap_size_ratio_config'.freeze

    def implementation
      'openj9'
    end

    def id(version)
      "openj9-#{version}"
    end

    def memory_opts
      java_memory_opts = []
      java_memory_opts.push '-Xtune:virtualized'

      java_memory_opts
    end

    def heap_size_ratio_file
      File.join(@app_dir, MEMORY_CONFIG_FOLDER, HEAP_RATIO_FILE)
    end

    def write_heap_size_ratio_file
      FileUtils.mkdir_p File.join(@app_dir, MEMORY_CONFIG_FOLDER)
      File.open(heap_size_ratio_file, 'w') { |file| file.write(heap_size_ratio) }
    end

    def heap_size_ratio
      @configuration['heap_size_ratio'] || HEAP_SIZE_RATIO
    end

    # default options for -Xdump to disable dumps while routing to the default dumps location when it is enabled by the
    # user
    def default_dump_opts
      default_options = []
      default_options.push '-Xdump:none'
      default_options.push "-Xdump:heap:defaults:file=#{@common_paths.dump_directory}/heapdump.%Y%m%d.%H%M%S.%pid.%seq.phd"
      default_options.push "-Xdump:java:defaults:file=#{@common_paths.dump_directory}/javacore.%Y%m%d.%H%M%S.%pid.%seq.txt"
      default_options.push "-Xdump:snap:defaults:file=#{@common_paths.dump_directory}/Snap.%Y%m%d.%H%M%S.%pid.%seq.trc"
      default_options.push '-Xdump:heap+java+snap:events=user'
      default_options
    end

    def copy_killjava_script
      resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
      killjava_file_content = File.read(File.join(resources, KILLJAVA_FILE_NAME))
      updated_content = killjava_file_content.gsub(/@@LOG_FILE_NAME@@/, LibertyBuildpack::Diagnostics::LOG_FILE_NAME)
      diagnostic_dir = LibertyBuildpack::Diagnostics.get_diagnostic_directory @app_dir
      FileUtils.mkdir_p diagnostic_dir
      File.open(File.join(diagnostic_dir, KILLJAVA_FILE_NAME), 'w', 0o755) do |file|
        file.write updated_content
      end
    end

  end

end

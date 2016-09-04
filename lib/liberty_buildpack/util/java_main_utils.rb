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

require 'liberty_buildpack/util/configuration_utils'
require 'liberty_buildpack/util'
require 'liberty_buildpack/util/properties'

module LibertyBuildpack::Util

  # Java Main application utilities.
  class JavaMainUtils

    private_class_method :new

    class << self

      # Returns the Java main class name for the Java main configuration and given application directory or +nil+ if this
      # is not a Java main application.
      #
      # @param [String] app_dir the directory of the application
      # @param [Hash] configuration the Java main configuration or +nil+ if this is not provided
      # @return [String, nil] the Java main class name or +nil+ if there is no Java main class name
      def main_class(app_dir, configuration = nil)
        configuration[MAIN_CLASS_PROPERTY] || manifest(app_dir)[MANIFEST_PROPERTY]
      end

      # Return the manifest properties of the given application.
      #
      # @param [String] app_dir the directory of the application
      # @return [Properties] the properties from the application's manifest (if any)
      def manifest(app_dir)
        manifest_file = File.join(app_dir, 'META-INF/MANIFEST.MF')
        manifest_file = File.exist?(manifest_file) ? manifest_file : nil
        LibertyBuildpack::Util::Properties.new(manifest_file)
      end

      MAIN_CLASS_PROPERTY = 'java_main_class'.freeze

      MANIFEST_PROPERTY = 'Main-Class'.freeze

      private_constant :MAIN_CLASS_PROPERTY, :MANIFEST_PROPERTY

    end

  end

end

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

require 'liberty_buildpack/util'
require 'liberty_buildpack/diagnostics/logger_factory'

module LibertyBuildpack::Util
  # A class to help locate Liberty server configuration files using
  # either standard Liberty properties or the relative location of
  # the configuration file.
  class LocationResolver
    # Creates an instance.
    #
    # @param wlp_install_dir [String] :the WLP installation directory
    # @param server_name [String] :the name of the server
    def initialize(app_dir, wlp_install_dir, server_name)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = app_dir
      @properties = {
        wlp_install_dir: wlp_install_dir,
        wlp_user_dir: wlp_install_dir + '/usr',
        usr_extension_dir: wlp_install_dir + '/usr/extension',
        shared_app_dir: wlp_install_dir + '/usr/shared/apps',
        shared_config_dir: wlp_install_dir + '/usr/shared/config',
        shared_resource_dir: wlp_install_dir + '/usr/shared/resources',
        server_config_dir: wlp_install_dir + '/usr/servers/' + server_name,
        server_output_dir: wlp_install_dir + '/usr/servers/' + server_name
      }
    end

    # Return the absolute path to the server configuration file.
    def absolute_path(config_file, server_xml_dir)
      result = config_file.clone
      @properties.each do |symbol, mapping|
        variable = symbol.to_s.tr "\_", '.'
        result.gsub! "\$\{#{variable}\}", mapping
      end
      result = File.expand_path(result, server_xml_dir)
      unless result.start_with?(@app_dir)
        raise "Absolute path must start with #{@app_dir} directory: #{result}"
      end
      result
    end
  end
end

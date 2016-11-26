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
        'wlp.install.dir' => wlp_install_dir,
        'wlp.user.dir' => wlp_install_dir + '/usr',
        'usr.extension.dir' => wlp_install_dir + '/usr/extension',
        'shared.app.dir' => wlp_install_dir + '/usr/shared/apps',
        'shared.config.dir' => wlp_install_dir + '/usr/shared/config',
        'shared.resource.dir' => wlp_install_dir + '/usr/shared/resources',
        'server.config.dir' => wlp_install_dir + '/usr/servers/' + server_name,
        'server.output.dir' => wlp_install_dir + '/usr/servers/' + server_name
      }
      @env = ENV.to_hash
      server_env = File.join(wlp_install_dir, 'usr', 'servers', server_name, 'server.env')
      load_server_env(server_env) if File.exist?(server_env)
    end

    # Return the absolute path to the server configuration file.
    def absolute_path(config_file, server_xml_dir)
      result = config_file.gsub(/(\$\{.+?\})/) do |match|
        if match =~ /\$\{env\./i
          var_name = match[6..-2]
          match = @env[var_name] unless @env[var_name].nil?
        else
          var_name = match[2..-2]
          match = @properties[var_name] unless @properties[var_name].nil?
        end
        match
      end
      result = File.expand_path(result, server_xml_dir)
      unless result.start_with?(@app_dir)
        raise "Absolute path must start with #{@app_dir} directory: #{result}"
      end
      result
    end

    private

    def load_server_env(server_env_file)
      File.open(server_env_file, 'r') do |file|
        file.each_line do |line|
          line.chomp!
          next if line.empty? || line.start_with?('#')
          index = line.index('=')
          next if index.nil?
          key = line[0..index - 1]
          value = line[index + 1..-1]
          @env[key] = value
        end
      end
    end

  end
end

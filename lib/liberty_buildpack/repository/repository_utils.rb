# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2016 the original author or authors.
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

require 'liberty_buildpack/diagnostics/logger_factory'

module LibertyBuildpack
  module Repository

    # A collection of utility functions for repositories.
    class RepositoryUtils

      def initialize
        @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger

        @@platform ||= platform
        @@architecture ||= architecture
        @@default_repository_root ||= LibertyBuildpack::Util::ConfigurationUtils.load('repository')['default_repository_root']
                                                                                .chomp('/')
      end

      # Resolves a repository url that may contain variables such as {default.repository.root}
      # {platform}, or {architecture}.
      #
      # @param [String] an url to resolve
      # @return [String] resolved url
      def resolve_uri(raw)
        cooked = raw
                 .gsub(/\{default.repository.root\}/, @@default_repository_root)
                 .gsub(/\{platform\}/, @@platform)
                 .gsub(/\{architecture\}/, @@architecture)
                 .chomp('/')
        @logger.debug { "#{raw} expanded to #{cooked}" }
        cooked
      end

      private

      def architecture
        `uname -m`.strip
      end

      def platform
        redhat_release = Pathname.new('/etc/redhat-release')

        if redhat_release.exist?
          tokens = redhat_release.read.match(/(\w+) (?:Linux )?release (\d+)/)
          "#{tokens[1].downcase}#{tokens[2]}"
        elsif `uname -s` =~ /Darwin/
          'mountainlion'
        elsif !`which lsb_release 2> /dev/null`.empty?
          `lsb_release -cs`.strip
        else
          raise 'Unable to determine platform'
        end
      end

    end

  end
end

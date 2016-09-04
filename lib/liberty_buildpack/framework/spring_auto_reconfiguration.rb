# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'liberty_buildpack/framework'
require 'liberty_buildpack/framework/framework_utils'
require 'liberty_buildpack/framework/spring_auto_reconfiguration/web_xml_modifier'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/download'
require 'liberty_buildpack/util/format_duration'

module LibertyBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for enabling cloud auto-reconfiguration in Spring
  # applications.
  class SpringAutoReconfiguration

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :lib_directory the directory that additional libraries are placed in
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context = {})
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @lib_directory = context[:lib_directory]
      @configuration = context[:configuration]
      @app_dir = context[:app_dir]
    end

    # Detects whether this application is suitable for auto-reconfiguration
    #
    # @return [String] returns +spring-auto-reconfiguration-<version>+ if the application is a candidate for
    #                  auto-reconfiguration otherwise returns +nil+
    def detect
      @auto_reconfiguration_version, @auto_reconfiguration_uri = SpringAutoReconfiguration.find_auto_reconfiguration(@app_dir, @configuration)
      @auto_reconfiguration_version ? id(@auto_reconfiguration_version) : nil
    end

    # Downloads the Auto-reconfiguration JAR
    #
    # @return [void]
    def compile
      detect if @auto_reconfiguration_uri.nil?
      LibertyBuildpack::Util.download(@auto_reconfiguration_version, @auto_reconfiguration_uri, 'Auto Reconfiguration', jar_name(@auto_reconfiguration_version), @lib_directory)
      FrameworkUtils.link_libs(SpringAutoReconfiguration.spring_apps(@app_dir), @lib_directory)
      SpringAutoReconfiguration.spring_apps(@app_dir).each { |app| modify_web_xml(app) }
    end

    # Does nothing
    #
    # @return [void]
    def release
    end

    private

    SPRING_JAR_PATTERN = 'spring-core*.jar'.freeze
    SPRING_APPS_PATTERN = "#{@app_dir}/**/#{SPRING_JAR_PATTERN}".freeze

    WEB_XML = File.join 'WEB-INF', 'web.xml'

    def self.find_auto_reconfiguration(app_dir, configuration)
      if enabled?(configuration) && spring_application?(app_dir)
        version, uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration)
      else
        version = nil
        uri = nil
      end
      return version, uri # rubocop:disable RedundantReturn
    end

    def self.enabled?(configuration)
      configuration['enabled'].nil? || configuration['enabled']
    end

    def id(version)
      "spring-auto-reconfiguration-#{version}"
    end

    def jar_name(version)
      "#{id version}.jar"
    end

    def modify_web_xml(app_dir)
      web_xml = File.join app_dir, WEB_XML

      if File.exist? web_xml
        puts '       Modifying /WEB-INF/web.xml for Auto Reconfiguration'
        @logger.debug { "  Original web.xml: #{File.read web_xml}" }

        modifier = File.open(web_xml) { |file| WebXmlModifier.new(file) }
        modifier.augment_root_context
        modifier.augment_servlet_contexts

        File.open(web_xml, 'w') { |file| file.write(modifier.to_s) }
        @logger.debug { "  Modified web.xml: #{File.read web_xml}" }
      end
    end

    def self.spring_application?(app_dir)
      SpringAutoReconfiguration.spring_apps(app_dir) != []
    end

    def self.spring_apps(app_dir)
      pattern = "#{app_dir}/**/#{SPRING_JAR_PATTERN}"
      (shared_libs = FrameworkUtils.find_shared_libs(app_dir, pattern)) unless Dir.glob("#{app_dir}/**/wlp").each { |file| File.directory? file }.empty?
      if !shared_libs.nil? && !shared_libs.empty?
        s_apps = FrameworkUtils.find(app_dir)
      else
        s_apps = FrameworkUtils.find(app_dir, pattern)
      end
      s_apps
    end
  end

end

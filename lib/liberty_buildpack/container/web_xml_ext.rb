# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2015 the original author or authors.
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
require 'liberty_buildpack/util/xml_utils'

module LibertyBuildpack::Container

  # The class that provides abstractions for ibm-web-ext.xml file.
  class WebXmlExt

    # Reads ibm-web-ext.xml file.
    #
    # @return [WebXmlExt] returns +nil+ if file does not exist or is malformed.
    def self.read(ibm_web_ext)
      if File.exist?(ibm_web_ext)
        begin
          return WebXmlExt.new(LibertyBuildpack::Util::XmlUtils.read_xml_file(ibm_web_ext))
        rescue => e
          logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
          logger.debug("Error reading ibm-web-ext.xml file: Exception #{e.message}")
        end
      end
      nil
    end

    def initialize(doc = nil)
      @doc = doc
    end

    # Returns context-root specified in the ibm-web-ext.xml file.
    #
    # @return [String] returns context-root specified in the file.
    def get_context_root
      unless @doc.nil?
        element = @doc.elements['/web-ext/context-root']
        return element.attributes['uri'] unless element.nil?
      end
      nil
    end

  end
end

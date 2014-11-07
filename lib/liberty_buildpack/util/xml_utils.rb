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

require 'liberty_buildpack'

module LibertyBuildpack::Util

  # XML-based utilities
  class XmlUtils

    #---------------------------------------------------------------------
    # A utility method that can be used to read XML file.
    #
    # @param filename - the name of the xml file to read.
    # @return [REXML::Document] the xml document.
    #-----------------------------------------------------------------------
    def self.read_xml_file(filename)
      xml_doc = File.open(filename, 'r:utf-8') { |file| REXML::Document.new(file) }
      xml_doc.context[:attribute_quote] = :quote
      xml_doc
    end

    #---------------------------------------------------------------------
    # A utility method that returns a pretty xml formatter.
    #
    # @return [REXML::Formatters::Pretty] pretty xml formatter
    #-----------------------------------------------------------------------
    def self.xml_formatter
      formatter = REXML::Formatters::Pretty.new(4)
      formatter.compact = true
      formatter.width = 256
      formatter
    end

    #---------------------------------------------------------------------
    # A utility method that can be used to write an REMXL::Document to a file with formatting.
    #
    # @param doc - the REXML::Document containing the document contents to write.
    # @param filename - the name of the file to write to.
    #-----------------------------------------------------------------------
    def self.write_formatted_xml_file(doc, filename)
      File.open(filename, 'w:utf-8') { |file| xml_formatter.write(doc, file) }
    end

  end

end

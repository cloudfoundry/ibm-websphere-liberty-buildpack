# Encoding: utf-8
# IBM Liberty Buildpack
# Copyright 2014 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require 'spec_helper'
require 'rexml/document'
require 'liberty_buildpack/util/xml_utils'

describe LibertyBuildpack::Util do

  describe 'write_formatted_xml_file' do
    #----------------
    # Helper method to check an xml file against expected results.
    #
    # @param xml - the name of the xml file file containing the results
    # @param - expected - the array of strings we expect to find in the xml file, in order.
    #----------------
    def validate_xml(server_xml, expected)
      server_xml_contents = File.readlines(server_xml)
      # For each String in the expected array, make sure there is a corresponding entry in server.xml
      # make sure we consume all entries in the expected array.
      expected.each_with_index do |value, index|
        expect(server_xml_contents[index].strip).to include(value)
      end
    end

    it 'should write long text fields with spaces' do
      Dir.mktmpdir do |root|
        # create the document and set the context similarly to how it will be set in buildpack code.
        server_xml_file = File.join(root, 'server.xml')
        server_xml_doc = REXML::Document.new('<server></server>')
        server_xml_doc.context[:attribute_quote] = :quote
        doc = server_xml_doc.root
        string1 = 'a big long string with a lot of spaces in it that seems to go on forever and ever and ever'
        string2 = 'another big long string with a lot of spaces it. This string also ; contains : some * punctuation - marks'
        # add an element, then add a couple of attributes with long names with spaces.
        element = REXML::Element.new('myElement', doc)
        element.add_attribute('anAttribute', string1)
        element.add_attribute('anotherAttribute', string2)
        # add a nested element
        element2 = REXML::Element.new('yourElement', element)
        text = "#{string1} ; #{string2}"
        element2.add_text(text)
        LibertyBuildpack::Util::XmlUtils.write_formatted_xml_file(server_xml_doc, server_xml_file)
        # Assemble expected results to check against the xml file we just wrote.
        s1 = '<server>'
        s2 = "<myElement anAttribute='#{string1}' anotherAttribute='#{string2}'>"
        s3 = "<yourElement>#{string1} ; #{string2}</yourElement>"
        s4 = '</myElement>'
        s5 = '</server>'
        expected = [s1, s2, s3, s4, s5]
        validate_xml(server_xml_file, expected)
      end
    end # it
  end # write_formatted_xml_file
end

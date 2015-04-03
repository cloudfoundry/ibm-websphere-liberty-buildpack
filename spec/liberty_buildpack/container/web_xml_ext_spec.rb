# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2015 the original author or authors.
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
require 'logging_helper'
require 'liberty_buildpack/container/web_xml_ext'

module LibertyBuildpack::Container

  describe WebXmlExt do
    include_context 'logging_helper'

    it 'should handle file that does not exist' do
      ibm_web_xml = LibertyBuildpack::Container::WebXmlExt.read('doesnotexist')
      expect(ibm_web_xml).to be_nil
    end

    it 'should handle malformed file' do
      ibm_web_xml = LibertyBuildpack::Container::WebXmlExt.read('spec/fixtures/ibm-web-ext-bad.xml')
      expect(ibm_web_xml).to be_nil
    end

    it 'should handle file without context-root' do
      ibm_web_xml = LibertyBuildpack::Container::WebXmlExt.read('spec/fixtures/ibm-web-ext-no-context.xml')
      expect(ibm_web_xml).not_to be_nil
      expect(ibm_web_xml.get_context_root).to be_nil
    end

    it 'should handle file with context-root' do
      ibm_web_xml = LibertyBuildpack::Container::WebXmlExt.read('spec/fixtures/ibm-web-ext.xml')
      expect(ibm_web_xml).not_to be_nil
      expect(ibm_web_xml.get_context_root).to eq('myContext')
    end

  end

end

# Encoding: utf-8
# IBM Liberty Buildpack
# Copyright 2013 the original author or authors.
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
require 'liberty_buildpack/services/utils'

module LibertyBuildpack::Services
  describe Utils do

    #----------------
    # Helper method to check an xml file agains expected results.
    #
    # @param xml - the name of the xml file file containing the results (server.xml, runtime_vars.xml)
    # @param - expected - the array of strings we expect to find in the xml file, in order.
    #----------------
    def validate_xml(server_xml, expected)
      # At present, with no formatter, REXML writes server.xml as a single line (no cr). If we write a special formatter in the future to change that,
      # then the following algorithm will need to change.
      server_xml_contents = File.readlines(server_xml)
      # For each String in the expected array, make sure there is a corresponding entry in server.xml
      # make sure we consume all entries in the expected array.
      expected.each do |line|
        expect(server_xml_contents[0]).to include(line)
      end
    end

    describe 'test add_features' do
      it 'should add a feature to existing featureManager' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          REXML::Element.new('featureManager', doc.root)
          Utils.add_features(doc.root, ['someFeature'])
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = '<featureManager><feature>someFeature</feature></featureManager>'
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should add multiple features to existing featureManager' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          REXML::Element.new('featureManager', doc.root)
          Utils.add_features(doc.root, %w(someFeature otherFeature))
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = '<featureManager><feature>someFeature</feature><feature>otherFeature</feature></featureManager>'
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should filter out duplicate features' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          REXML::Element.new('featureManager', doc.root)
          Utils.add_features(doc.root, %w(someFeature someFeature))
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = '<featureManager><feature>someFeature</feature></featureManager>'
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should handle partitioned featureManager' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          REXML::Element.new('featureManager', doc.root)
          fm = REXML::Element.new('featureManager', doc.root)
          f = REXML::Element.new('feature', fm)
          f.add_text('otherFeature')
          Utils.add_features(doc.root, %w(someFeature otherFeature))
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = '<featureManager><feature>someFeature</feature></featureManager>'
          s3 = '<featureManager><feature>otherFeature</feature></featureManager>'
          s4 = '</server>'
          expected = [s1, s2, s3, s4]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should raise when no featureManager exists' do
        doc = REXML::Document.new('<server></server>')
        expect { Utils.add_features(doc.root, %w(someFeature otherFeature)) }.to raise_error(RuntimeError, 'Feature Manager not found')
      end # it

      it 'should raise when doc is nil' do
        expect { Utils.add_features(nil, %w(someFeature otherFeature)) }.to raise_error(RuntimeError, 'invalid parameters')
      end # it

      it 'should raise when features is nil' do
        doc = REXML::Document.new('<server></server>')
        expect { Utils.add_features(doc.root, nil) }.to raise_error(RuntimeError, 'invalid parameters')
      end # it

      it 'should raise when features is empty' do
        doc = REXML::Document.new('<server></server>')
        expect { Utils.add_features(doc.root, []) }.to raise_error(RuntimeError, 'invalid parameters')
      end # it
    end # describe test add features

    describe 'test update_bootstrap_properties' do
      # This is currently tested in log_analysis_spec.rb
    end # describe test update bootstrap.properties

    describe 'test is_logical_singleton?' do
      it 'should handle single element with no config ids' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        expect(Utils.is_logical_singleton?([e1])).to be_true
      end # it

      it 'should handle partitioned element with no config ids' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e2 = REXML::Element.new('stanza', doc.root)
        expect(Utils.is_logical_singleton?([e1, e2])).to be_true
      end # it

      it 'should handle partitioned element with config ids' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e1.add_attribute('id', 'someid')
        e2 = REXML::Element.new('stanza', doc.root)
        e2.add_attribute('id', 'someid')
        expect(Utils.is_logical_singleton?([e1, e2])).to be_true
      end # it

      it 'should handle partitioned element with mismatched config ids' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e1.add_attribute('id', 'someid')
        e2 = REXML::Element.new('stanza', doc.root)
        e2.add_attribute('id', 'otherid')
        expect(Utils.is_logical_singleton?([e1, e2])).to be_false
      end # it

      it 'should handle partitioned element where first has id and second does not' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e1.add_attribute('id', 'someid')
        e2 = REXML::Element.new('stanza', doc.root)
        expect(Utils.is_logical_singleton?([e1, e2])).to be_false
      end # it

      it 'should handle partitioned element where second has id and first does not' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e2 = REXML::Element.new('stanza', doc.root)
        e2.add_attribute('id', 'someid')
        expect(Utils.is_logical_singleton?([e1, e2])).to be_false
      end # it
    end # describe test is_logical_singleton?

    describe 'test find_and_update_attribute' do
      it 'should create attribute when it does not exist in single element' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          e1 = REXML::Element.new('test', doc.root)
          Utils.find_and_update_attribute([e1], 'foo', 'bar')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<test foo='bar'/>"
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should create attribute when it does not exist in multiple elements' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          e1 = REXML::Element.new('test', doc.root)
          e1.add_attribute('fool', 'bar')
          e2 = REXML::Element.new('test', doc.root)
          e2.add_attribute('fo', 'bar')
          Utils.find_and_update_attribute([e1, e2], 'foo', 'bar')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<test fool='bar'/>"
          s3 = "<test fo='bar' foo='bar'/>"
          s4 = '</server>'
          expected = [s1, s2, s3, s4]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should update attribute when it exists in single element' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          e1 = REXML::Element.new('test', doc.root)
          e1.add_attribute('foo', 'bard')
          Utils.find_and_update_attribute([e1], 'foo', 'bar')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<test foo='bar'/>"
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should update attribute when it exists in one of multiple elements' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          e1 = REXML::Element.new('test', doc.root)
          e1.add_attribute('fool', 'bar')
          e2 = REXML::Element.new('test', doc.root)
          e2.add_attribute('foo', 'bard')
          Utils.find_and_update_attribute([e1, e2], 'foo', 'bar')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<test fool='bar'/>"
          s3 = "<test foo='bar'/>"
          s4 = '</server>'
          expected = [s1, s2, s3, s4]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should update attribute in all instances when it exists in multiple elements' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          e1 = REXML::Element.new('test', doc.root)
          e1.add_attribute('foo', 'bar1')
          e2 = REXML::Element.new('test', doc.root)
          e2.add_attribute('foo', 'bard')
          Utils.find_and_update_attribute([e1], 'foo', 'bar')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<test foo='bar'/>"
          s3 = "<test foo='bar'/>"
          s4 = '</server>'
          expected = [s1, s2, s3, s4]
          validate_xml(server_xml, expected)
        end
      end # it
    end # describe test find_and_update_attribute

    describe 'test find_attribute' do
    end # describe test find_attribute

    describe 'test get_applications' do
      it 'should return empty array if no applications' do
        doc = REXML::Document.new('<server></server>')
        expect(Utils.get_applications(doc.root).size).to eq(0)
      end # it

      it 'should detect single application' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'myapp')
        expect(Utils.get_applications(doc.root).size).to eq(1)
      end # it

      it 'should detect single webApplication' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('webApplication', doc.root)
        app.add_attribute('id', 'myapp')
        expect(Utils.get_applications(doc.root).size).to eq(1)
      end # it

      it 'should detect two application' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'myapp')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'other')
        expect(Utils.get_applications(doc.root).size).to eq(2)
      end # it

      it 'should detect two webApplication' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('webApplication', doc.root)
        app.add_attribute('id', 'myapp')
        app = REXML::Element.new('webApplication', doc.root)
        app.add_attribute('id', 'other')
        expect(Utils.get_applications(doc.root).size).to eq(2)
      end # it

      it 'should detect one application and one webApplication' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'myapp')
        app = REXML::Element.new('webApplication', doc.root)
        app.add_attribute('id', 'other')
        expect(Utils.get_applications(doc.root).size).to eq(2)
      end # it
    end # describe test get_applications

    describe 'test get_api_visibility' do
      it 'should return nil if no applications' do
        doc = REXML::Document.new('<server></server>')
        expect(Utils.get_api_visibility(doc.root)).to be_nil
      end # it

      it 'should return nil if multiple applications' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'myapp')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'yourid')
        expect(Utils.get_api_visibility(doc.root)).to be_nil
      end # it

      it 'should return nil if one application/no classloader' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'myapp')
        expect(Utils.get_api_visibility(doc.root)).to be_nil
      end # it

      it 'should return nil if one application/one classloader/no api' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'myapp')
        cl = REXML::Element.new('classloader', app)
        cl.add_attribute('id', 'cl_id')
        expect(Utils.get_api_visibility(doc.root)).to be_nil
      end # it

      it 'should return visibility if one application/one classloader/api' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'myapp')
        cl = REXML::Element.new('classloader', app)
        cl.add_attribute('id', 'cl_id')
        cl.add_attribute('apiTypeVisibility', 'ibm,spec')
        expect(Utils.get_api_visibility(doc.root)).to eq('ibm,spec')
      end # it

      it 'should return nil if one application/two classloader/no api' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'myapp')
        cl = REXML::Element.new('classloader', app)
        cl.add_attribute('id', 'cl_id')
        cl = REXML::Element.new('classloader', app)
        cl.add_attribute('id', 'cl_id')
        expect(Utils.get_api_visibility(doc.root)).to be_nil
      end # it

      it 'should return visibility if one application/two classloader/api' do
        doc = REXML::Document.new('<server></server>')
        app = REXML::Element.new('application', doc.root)
        app.add_attribute('id', 'myapp')
        cl = REXML::Element.new('classloader', app)
        cl.add_attribute('id', 'cl_id')
        cl = REXML::Element.new('classloader', app)
        cl.add_attribute('id', 'other')
        cl.add_attribute('apiTypeVisibility', 'ibm,spec')
        expect(Utils.get_api_visibility(doc.root)).to eq('ibm,spec')
      end # it
    end # describe test get_api_visibility

    describe 'test add_library_to_app_classloader' do
      it 'should do nothing if no applications' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          Utils.add_library_to_app_classloader(doc.root, 'debug', 'lib')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server/>'
          expected = [s1]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should do nothing if multiple applications' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          app = REXML::Element.new('application', doc.root)
          app.add_attribute('id', 'myapp')
          app = REXML::Element.new('application', doc.root)
          app.add_attribute('id', 'yourid')
          Utils.add_library_to_app_classloader(doc.root, 'debug', 'lib')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<application id='myapp'/>"
          s3 = "<application id='yourid'/>"
          s4 = '</server>'
          expected = [s1, s2, s3, s4]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should create classloader if it does not exist' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          app = REXML::Element.new('application', doc.root)
          app.add_attribute('id', 'myapp')
          Utils.add_library_to_app_classloader(doc.root, 'debug', 'lib')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<application id='myapp'><classloader commonLibraryRef='lib'/></application>"
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should add commonLibRef to classloader if it does not exist' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          app = REXML::Element.new('application', doc.root)
          app.add_attribute('id', 'myapp')
          cl = REXML::Element.new('classloader', app)
          cl.add_attribute('id', 'cl_id')
          Utils.add_library_to_app_classloader(doc.root, 'debug', 'lib')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<application id='myapp'><classloader commonLibraryRef='lib' id='cl_id'/></application>"
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should add update existing commonLibRef in classloader' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          app = REXML::Element.new('application', doc.root)
          app.add_attribute('id', 'myapp')
          cl = REXML::Element.new('classloader', app)
          cl.add_attribute('commonLibraryRef', 'first')
          Utils.add_library_to_app_classloader(doc.root, 'debug', 'lib')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<application id='myapp'><classloader commonLibraryRef='first,lib'/></application>"
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should do nothing if commonLibraryRef is already set' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          app = REXML::Element.new('application', doc.root)
          app.add_attribute('id', 'myapp')
          cl = REXML::Element.new('classloader', app)
          cl.add_attribute('commonLibraryRef', 'lib')
          Utils.add_library_to_app_classloader(doc.root, 'debug', 'lib')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<application id='myapp'><classloader commonLibraryRef='lib'/></application>"
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it

      it 'should do nothing if commonLibraryRef is already set and has multiple entries' do
        Dir.mktmpdir do |root|
          server_xml = File.join(root, 'server.xml')
          doc = REXML::Document.new('<server></server>')
          app = REXML::Element.new('application', doc.root)
          app.add_attribute('id', 'myapp')
          cl = REXML::Element.new('classloader', app)
          cl.add_attribute('commonLibraryRef', 'first, lib')
          Utils.add_library_to_app_classloader(doc.root, 'debug', 'lib')
          File.open(server_xml, 'w') { |file| doc.write(file) }
          # create the Strings to check server.xml contents
          s1 = '<server>'
          s2 = "<application id='myapp'><classloader commonLibraryRef='first, lib'/></application>"
          s3 = '</server>'
          expected = [s1, s2, s3]
          validate_xml(server_xml, expected)
        end
      end # it
    end # describe test add_library_to_app_classloader
  end # describe DataCache
end
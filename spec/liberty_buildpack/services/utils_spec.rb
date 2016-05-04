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
require 'liberty_buildpack/services/utils'
require 'logging_helper'

module LibertyBuildpack::Services
  describe Utils do
    include_context 'logging_helper'

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

      it 'should raise when doc is nil' do
        expect { Utils.add_features(nil, %w(someFeature otherFeature)) }.to raise_error(RuntimeError, 'invalid parameters')
      end # it

      it 'should raise when features is nil' do
        doc = REXML::Document.new('<server></server>')
        expect { Utils.add_features(doc.root, nil) }.to raise_error(RuntimeError, 'invalid parameters')
      end # it

      it 'should raise when feature conditionals are invalid' do
        doc = REXML::Document.new('<server></server>')

        condition = {}
        expect { Utils.add_features(doc.root, condition) }.to raise_error(RuntimeError, 'Invalid feature condition')

        condition = { 'if' => ['a'] }
        expect { Utils.add_features(doc.root, condition) }.to raise_error(RuntimeError, 'Invalid feature condition')

        condition = { 'then' => ['a'] }
        expect { Utils.add_features(doc.root, condition) }.to raise_error(RuntimeError, 'Invalid feature condition')

        condition = { 'else' => ['a'] }
        expect { Utils.add_features(doc.root, condition) }.to raise_error(RuntimeError, 'Invalid feature condition')
      end

      it 'should handle feature conditionals' do
        condition = { 'if' => ['servlet-3.0', 'jdbc-4.0'], 'then' => ['jsp-2.2'], 'else' => ['jsp-2.3'] }

        # should use jsp-2.3 because no feature is found
        doc = REXML::Document.new('<server></server>')
        Utils.add_features(doc.root, condition)
        features = Utils.get_features(doc.root)
        expect(features).to include('jsp-2.3')

        # should use jsp-2.2 because servlet-3.0 is found
        doc = REXML::Document.new('<server></server>')
        Utils.add_features(doc.root, %w(servlet-3.0))
        Utils.add_features(doc.root, condition)
        features = Utils.get_features(doc.root)
        expect(features).to include('servlet-3.0', 'jsp-2.2')

        # should use jsp-2.2 becuase jdbc-4.0 is found
        doc = REXML::Document.new('<server></server>')
        Utils.add_features(doc.root, %w(jdbc-4.0))
        Utils.add_features(doc.root, condition)
        features = Utils.get_features(doc.root)
        expect(features).to include('jdbc-4.0', 'jsp-2.2')
      end # it

    end # describe test add features

    describe 'test update_bootstrap_properties' do
      # This is currently tested in log_analysis_spec.rb
    end # describe test update bootstrap.properties

    describe 'test is_logical_singleton?' do
      it 'should handle single element with no config ids' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        expect(Utils.is_logical_singleton?([e1])).to eq(true)
      end # it

      it 'should handle partitioned element with no config ids' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e2 = REXML::Element.new('stanza', doc.root)
        expect(Utils.is_logical_singleton?([e1, e2])).to eq(true)
      end # it

      it 'should handle partitioned element with config ids' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e1.add_attribute('id', 'someid')
        e2 = REXML::Element.new('stanza', doc.root)
        e2.add_attribute('id', 'someid')
        expect(Utils.is_logical_singleton?([e1, e2])).to eq(true)
      end # it

      it 'should handle partitioned element with mismatched config ids' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e1.add_attribute('id', 'someid')
        e2 = REXML::Element.new('stanza', doc.root)
        e2.add_attribute('id', 'otherid')
        expect(Utils.is_logical_singleton?([e1, e2])).to eq(false)
      end # it

      it 'should handle partitioned element where first has id and second does not' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e1.add_attribute('id', 'someid')
        e2 = REXML::Element.new('stanza', doc.root)
        expect(Utils.is_logical_singleton?([e1, e2])).to eq(false)
      end # it

      it 'should handle partitioned element where second has id and first does not' do
        doc = REXML::Document.new('<server></server>')
        e1 = REXML::Element.new('stanza', doc.root)
        e2 = REXML::Element.new('stanza', doc.root)
        e2.add_attribute('id', 'someid')
        expect(Utils.is_logical_singleton?([e1, e2])).to eq(false)
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

    describe 'get_urls_for_client_jars' do

      it 'via client_jar_key' do
        config = {}
        config['client_jar_key'] = 'myKey'
        urls = {}
        urls['myKey'] = 'http://myHost/myPath'

        result = Utils.get_urls_for_client_jars(config, urls)
        expect(result).to include(urls['myKey'])
      end

      it 'via client_jar_url' do
        config = {}
        config['client_jar_url'] = 'http://myHost/myPath'
        urls = {}

        result = Utils.get_urls_for_client_jars(config, urls)
        expect(result).to include(config['client_jar_url'])
      end

      it 'via client_jar_url with variable' do
        config = {}
        config['client_jar_url'] = '{default_repository_root}/myPath'
        urls = {}

        result = Utils.get_urls_for_client_jars(config, urls)
        expected = 'https://download.run.pivotal.io/myPath'
        expect(result).to include(expected)
      end

      it 'via driver' do
        data = [LibertyBuildpack::Util::TokenizedVersion.new('1.5.0'), 'http://myHost/myPath']
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(data)

        driver = {}
        driver['repository_root'] = 'file://doesnotmatter'
        driver['version'] = '1.+'
        config = {}
        config['driver'] = driver
        urls = {}

        result = Utils.get_urls_for_client_jars(config, urls)
        expect(result).to include('http://myHost/myPath')
      end

    end # describe

    describe 'parse_compliant_vcap_service' do

      let(:vcap_services) do
        { 'myName' =>
          [{ 'name' => 'myName',
              'plan' => 'beta',
              'label' => 'myLabel',
              'credentials' => {
                'url' => 'http://foobar',
                'password' => 'myPassword',
                'scopes' => %w(singleton request)
              }
            }]
        }
      end

      def test_result(generated_hash, generated_xml, name, value)
        expect(generated_hash[name]).to eq(value)

        variables = REXML::XPath.match(generated_xml, "/server/variable[@name='#{name}']")
        expect(variables).not_to be_empty
        expect(variables[0].attributes['value']).to eq(value)
      end

      it 'parse default' do
        doc = REXML::Document.new('<server></server>')
        hash = Utils.parse_compliant_vcap_service(doc.root, vcap_services['myName'][0])

        test_result(hash, doc.root, 'cloud.services.myName.name', 'myName')
        test_result(hash, doc.root, 'cloud.services.myName.plan', 'beta')
        test_result(hash, doc.root, 'cloud.services.myName.label', 'myLabel')
        test_result(hash, doc.root, 'cloud.services.myName.connection.url', 'http://foobar')
        test_result(hash, doc.root, 'cloud.services.myName.connection.password', 'myPassword')
        test_result(hash, doc.root, 'cloud.services.myName.connection.scopes', 'singleton, request')
      end

      it 'parse custom' do
        doc = REXML::Document.new('<server></server>')
        hash = Utils.parse_compliant_vcap_service(doc.root, vcap_services['myName'][0]) do | name, value |
          if name == 'credentials.scopes'
            value = value.join(' ')
          elsif name == 'plan'
            value = 'alpha'
          else
            value
          end
        end

        test_result(hash, doc.root, 'cloud.services.myName.name', 'myName')
        test_result(hash, doc.root, 'cloud.services.myName.plan', 'alpha')
        test_result(hash, doc.root, 'cloud.services.myName.label', 'myLabel')
        test_result(hash, doc.root, 'cloud.services.myName.connection.url', 'http://foobar')
        test_result(hash, doc.root, 'cloud.services.myName.connection.password', 'myPassword')
        test_result(hash, doc.root, 'cloud.services.myName.connection.scopes', 'singleton request')
      end

    end

  end # describe
end

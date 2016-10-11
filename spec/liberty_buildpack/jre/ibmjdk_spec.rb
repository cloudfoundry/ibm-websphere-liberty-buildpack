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

require 'spec_helper'
require 'component_helper'
require 'fileutils'
require 'liberty_buildpack/jre/ibmjdk'

module LibertyBuildpack::Jre

  describe IBMJdk do
    include_context 'component_helper'

    let(:application_cache) { double('ApplicationCache') }

    before do |example|
      # By default, always stub the return of a valid ibmjdk_config.yml against a given service_release as indicated by
      # the spec test's service_release metadata.  Tests that test for errors can disable a valid return of the
      # ibmjdk_config.yml by setting its find_item metadata to false along with the optional expected error
      find_item = example.metadata[:return_find_item].nil? ? true : example.metadata[:return_find_item]
      if find_item
        token_version = example.metadata[:service_release]

        ibmjdk_config = [LibertyBuildpack::Util::TokenizedVersion.new(token_version), { 'uri' => uri, 'license' => 'spec/fixtures/license.html' }]
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(ibmjdk_config)
      else
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_raise(example.metadata[:raise_error_message])
      end

      # return license file by default
      application_cache.stub(:get).and_yield(File.open('spec/fixtures/license.html'))

    end

    # tests for common behaviors across IBMJDK v7 releases
    shared_examples_for 'IBMJDK v7' do |service_release|

      it 'adds the JAVA_HOME to java_home', java_home: '', java_opts: [], license_ids: {} do |example|

        java_home = example.metadata[:java_home]

        # context is provided by component_helper, its default values are provided by 'describe' metadata, and
        # customized through test's metadata
        IBMJdk.new(context)

        expect(java_home).to eq('.java')
      end

      describe 'detect', java_home: '', license_ids: {}, service_release: service_release do

        # context is provided by component_helper, its default values are provided by 'describe' metadata, and
        # customized through test's metadata
        subject(:detected) { IBMJdk.new(context).detect }

        it 'should detect with id of ibmjdk-<version>' do
          expect(detected).to eq('ibmjdk-' + service_release)
        end

        it 'should fail when ConfiguredItem.find_item fails', return_find_item: false, raise_error_message: 'test error' do
          expect { detected }.to raise_error(/IBM\ JRE\ error:\ test\ error/)
        end
      end # end of detect shared tests

      describe 'compile',
               java_home: '',
               java_opts: [],
               configuration: {},
               license_ids: { 'IBM_JVM_LICENSE' => '1234-ABCD' },
               service_release: service_release do

        before do |example|
          # get the application cache fixture from the application_cache double provided in the overall setup
          LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
          cache_fixture = example.metadata[:cache_fixture]
          application_cache.stub(:get).with(uri).and_yield(File.open("spec/fixtures/#{cache_fixture}")) if cache_fixture
        end

        # context is provided by component_helper, its default values are provided by 'describe' metadata, and
        # customized through test's metadata
        subject(:compiled) { IBMJdk.new(context).compile }

        it 'should extract Java from a bin script', cache_fixture: 'stub-ibm-java.bin' do
          compiled

          java = File.join(app_dir, '.java', 'jre', 'bin', 'java')
          expect(File.exist?(java)).to eq(true)
        end

        it 'should extract Java from a tar gz', cache_fixture: 'stub-ibm-java.tar.gz' do
          compiled

          java = File.join(app_dir, '.java', 'jre', 'bin', 'java')
          expect(File.exist?(java)).to eq(true)
        end

        it 'should not display Avoid Trouble message when specifying 512MB or higher mem limit', cache_fixture: 'stub-ibm-java.tar.gz' do
          ENV['MEMORY_LIMIT'] = '512m'

          expect { compiled }.not_to output(/Avoid Trouble/).to_stdout
        end

        it 'should display Avoid Trouble message when specifying <512MB mem limit', cache_fixture: 'stub-ibm-java.tar.gz' do
          ENV['MEMORY_LIMIT'] = '256m'

          expect { compiled }.to output(/Avoid Trouble/).to_stdout
        end

        it 'should fail when the license id is not provided', app_dir: '', license_ids: {} do
          expect { compiled }.to raise_error
        end

        it 'should fail when the license ids do not match', app_dir: '', license_ids: { 'IBM_JVM_LICENSE' => 'Incorrect' } do
          expect { compiled }.to raise_error
        end

        it 'should not fail when the license url is not provided', app_dir: '', license_ids: {}, cache_fixture: 'stub-ibm-java.tar.gz' do
          ibmjdk_config = [LibertyBuildpack::Util::TokenizedVersion.new(service_release), { 'uri' => uri }]
          LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(ibmjdk_config)

          compiled

          java = File.join(app_dir, '.java', 'jre', 'bin', 'java')
          expect(File.exist?(java)).to eq(true)
        end

        it 'places the killjava script (with appropriately substituted content) in the diagnostics directory', cache_fixture: 'stub-ibm-java.bin' do
          compiled

          expect(Pathname.new(File.join(LibertyBuildpack::Diagnostics.get_diagnostic_directory(app_dir), IBMJdk::KILLJAVA_FILE_NAME))).to exist
        end

      end # end of compile shared tests

      describe 'release',
               java_home: '',
               java_opts: [],
               configuration: {},
               license_ids: { 'IBM_JVM_LICENSE' => '1234-ABCD' },
               service_release: service_release do

        # context is provided by component_helper, its default values are provided by 'describe' metadata, and
        # customized through test's metadata
        subject(:released) do
          component = IBMJdk.new(context)
          component.detect
          component.release
        end

        it 'should add default dump options that output data to the common dumps directory, if enabled' do
          expect(released).to include('-Xdump:none',
                                      '-Xshareclasses:none',
                                      '-Xdump:heap:defaults:file=./../dumps/heapdump.%Y%m%d.%H%M%S.%pid.%seq.phd',
                                      '-Xdump:java:defaults:file=./../dumps/javacore.%Y%m%d.%H%M%S.%pid.%seq.txt',
                                      '-Xdump:snap:defaults:file=./../dumps/Snap.%Y%m%d.%H%M%S.%pid.%seq.trc',
                                      '-Xdump:heap+java+snap:events=user')
        end

        it 'should add extra memory options when 512m memory limit is set' do
          ENV['MEMORY_LIMIT'] = '512m'

          expect(released).to include('-Xtune:virtualized')
          expect(released).to include('-Xmx384M')
        end

        it 'should add extra memory options when 512m memory limit is set with 50% ratio', configuration: { 'heap_size_ratio' => 0.50 } do
          ENV['MEMORY_LIMIT'] = '512m'

          expect(released).to include('-Xtune:virtualized')
          expect(released).to include('-Xmx256M')
        end

        it 'should add extra memory options when 1024m memory limit is set' do
          ENV['MEMORY_LIMIT'] = '1024m'

          expect(released).to include('-Xtune:virtualized')
          expect(released).to include('-Xmx768M')
        end

        it 'should add extra memory options when 1024m memory limit is set with 12.% ratio', configuration: { 'heap_size_ratio' => 0.125 } do
          ENV['MEMORY_LIMIT'] = '1024m'

          expect(released).to include('-Xtune:virtualized')
          expect(released).to include('-Xmx128M')
        end

        it 'should provide troubleshooting info for JVM shutdowns' do
          expect(released).to include("-Xdump:tool:events=systhrow,filter=java/lang/OutOfMemoryError,request=serial+exclusive,exec=./#{LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{IBMJdk::KILLJAVA_FILE_NAME}")
        end
      end # end of release shared tests

    end # end of shared tests for IBMJDK v7 release

    context 'IBMJDK Service Release 1.7.1' do
      it_behaves_like 'IBMJDK v7', '1.7.1'
    end

    describe 'TLS options',
             java_home: '',
             java_opts: [],
             license_ids: { 'IBM_JVM_LICENSE' => '1234-ABCD' } do

      # context is provided by component_helper, its default values are provided by 'describe' metadata, and
      # customized through test's metadata
      subject(:released) do
        component = IBMJdk.new(context)
        component.detect
        component.release
      end

      it 'should add appropriate TLS options for Java 1.8', java_opts: [], service_release: '1.8.0' do
        expect(released).to include('-Dcom.ibm.jsse2.overrideDefaultTLS=true')
        expect(released).not_to include('-Dcom.ibm.jsse2.overrideDefaultProtocol=SSL_TLSv2')
      end

      it 'should add appropriate TLS options for Java 1.7', java_opts: [], service_release: '1.7.1' do
        expect(released).to include('-Dcom.ibm.jsse2.overrideDefaultTLS=true')
        expect(released).to include('-Dcom.ibm.jsse2.overrideDefaultProtocol=SSL_TLSv2')
      end

    end
  end

end

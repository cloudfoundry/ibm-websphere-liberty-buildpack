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

    CURRENT_SERVICE_RELEASE = '1.7.0'.freeze

    let(:application_cache) { double('ApplicationCache') }

    # tests for common behaviors across IBMJDK v7 releases
    shared_examples_for 'IBMJDK v7' do | service_release |

      before do | example |
        # By default, always stub the return of a valid ibmjdk_config.yml against a given service_release as indicated by
        # the spec test's service_release metadata.  Tests that test for errors can disable a valid return of the
        # ibmjdk_config.yml by setting its find_item metadata to false along with the optional expected error
        token_version = example.metadata[:service_release]
        ibmjdk_config = [LibertyBuildpack::Util::TokenizedVersion.new(token_version), uri, 'spec/fixtures/license.html']
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(ibmjdk_config)
        # return license file by default
        application_cache.stub(:get).and_yield(File.open('spec/fixtures/license.html'))
      end

      it 'adds the JAVA_HOME to java_home', java_home: '', java_opts: [], license_ids: {} do | example |

        java_home = example.metadata[:java_home]

        # context is provided by component_helper, its default values are provided by 'describe' metadata, and
        # customized through test's metadata
        IBMJdk.new(context)

        expect(java_home).to eq('.java')
      end

      describe 'compile',
               java_home: '',
               java_opts: [],
               configuration: {},
               license_ids: { 'IBM_JVM_LICENSE' => '1234-ABCD' },
               service_release: service_release do

        before do | example |
          # get the application cache fixture from the application_cache double provided in the overall setup
          LibertyBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          cache_fixture = example.metadata[:cache_fixture]
          application_cache.stub(:get).with(uri).and_yield(File.open("spec/fixtures/#{cache_fixture}")) if cache_fixture
        end

        # context is provided by component_helper, its default values are provided by 'describe' metadata, and
        # customized through test's metadata
        subject(:compiled) { IBMJdk.new(context).compile }

        it 'should extract Java from a bin script', cache_fixture: 'stub-ibm-java.bin'  do
          compiled

          java = File.join(app_dir, '.java', 'jre', 'bin', 'java')
          expect(File.exists?(java)).to eq(true)
        end

        it 'should extract Java from a tar gz', cache_fixture: 'stub-ibm-java.tar.gz' do
          compiled

          java = File.join(app_dir, '.java', 'jre', 'bin', 'java')
          expect(File.exists?(java)).to eq(true)
        end

        it 'should not display Avoid Trouble message when specifying 512MB or higher mem limit', cache_fixture: 'stub-ibm-java.tar.gz' do
          ENV['MEMORY_LIMIT'] = '512m'

          expect { compiled }.not_to output(/Avoid Trouble/).to_stdout
        end

        it 'should display Avoid Trouble message when specifying <512MB mem limit', cache_fixture: 'stub-ibm-java.tar.gz' do
          ENV['MEMORY_LIMIT'] = '256m'

          expect { compiled }.to output(/Avoid Trouble/).to_stdout
        end

        it 'should fail when the license ids do not match', app_dir: '', license_ids: { 'IBM_JVM_LICENSE' => 'Incorrect' } do
          expect { compiled }.to raise_error
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
        subject(:released) { IBMJdk.new(context).release }

        it 'should add default dump options that output data to the common dumps directory, if enabled' do
          expect(released).to include('-Xdump:none',
                                      '-Xdump:heap:defaults:file=./../dumps/heapdump.%Y%m%d.%H%M%S.%pid.%seq.phd',
                                      '-Xdump:java:defaults:file=./../dumps/javacore.%Y%m%d.%H%M%S.%pid.%seq.txt',
                                      '-Xdump:snap:defaults:file=./../dumps/Snap.%Y%m%d.%H%M%S.%pid.%seq.trc',
                                      '-Xdump:heap+java+snap:events=user')
        end

        it 'should add extra memory options when a memory limit is set' do
          ENV['MEMORY_LIMIT'] = '512m'

          expect(released).to include('-Xtune:virtualized')
          expect(released).to include('-Xmx384M')
        end

        it 'should provide troubleshooting info for JVM shutdowns' do
          ENV['MEMORY_LIMIT'] = '512m'

          expect(released).to include("-Xdump:tool:events=systhrow,filter=java/lang/OutOfMemoryError,request=serial+exclusive,exec=./#{LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{IBMJdk::KILLJAVA_FILE_NAME}")
        end
      end # end of release shared tests

    end # end of shared tests for IBMJDK v7 release

    context 'IBMJDK Service Release 1.7.0' do
      it_behaves_like 'IBMJDK v7', '1.7.0'

      if CURRENT_SERVICE_RELEASE == '1.7.0'
        describe 'release',
                 java_home: '',
                 java_opts: [],
                 configuration: {},
                 license_ids: { 'IBM_JVM_LICENSE' => '1234-ABCD' },
                 service_release: '1.7.0' do

          # context is provided by component_helper, its default values are provided by 'describe' metadata, and
          # customized through test's metadata
          subject(:java_opts) { IBMJdk.new(context).release }

          it 'should used -Xnocompressedrefs when the memory limit is less than 256m' do
            ENV['MEMORY_LIMIT'] = '64m'

            expect(java_opts).to include('-Xtune:virtualized')
            expect(java_opts).to include('-Xmx48M')
            expect(java_opts).to include('-Xnocompressedrefs')
          end

          it 'should add memory options to java_opts' do
            ENV['MEMORY_LIMIT'] = nil

            expect(java_opts).to include('-Xnocompressedrefs')
            expect(java_opts).to include('-Xtune:virtualized')
          end
        end # end release
      end

    end
    context 'detect' do
      # We use an index.yml file in our tests, so we require config to get through the lookup. Since Bluemix overwrites ibmjdk.yml, use dummy config.
      config = { 'repository_root' => 'http://dummyurl', 'version' => '1.7.1_+', 'version_env_var' => 'LBP_IBMJDK_VERSION' }
      describe 'detect', java_home: '', configuration: config, license_ids: {} do

        before do |example|
          LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).and_yield(File.open('spec/fixtures/jre/ibmjdk/index.yml'))
        end

        after do |example|
          ENV['LBP_IBMJDK_VERSION'] = nil
        end

        subject(:detected) { IBMJdk.new(context).detect }

        it 'should return latest version of the default release when no version is specified' do
          expect(detected).to eq('ibmjdk-1.7.1_65')
        end

        it 'allows specification of major/minor release' do
           ENV['LBP_IBMJDK_VERSION'] = '1.8.+'
           expect(detected).to eq('ibmjdk-1.8.0_00')
        end

        it 'allows wildcarding of the micro release and qualifier' do
          ENV['LBP_IBMJDK_VERSION'] = '1.7.+'
          expect(detected).to eq('ibmjdk-1.7.1_65')
        end

        it 'automatically wildcards qualifier when not specified' do
          ENV['LBP_IBMJDK_VERSION'] = '1.7.1'
          expect(detected).to eq('ibmjdk-1.7.1_65')
        end

        it 'allows qualifier to be specified as a wildcard' do
          ENV['LBP_IBMJDK_VERSION'] = '1.7.1_+'
          expect(detected).to eq('ibmjdk-1.7.1_65')
        end

        it 'allows qualifer to be specified and honored' do
          ENV['LBP_IBMJDK_VERSION'] = '1.7.1_07'
          expect(detected).to eq('ibmjdk-1.7.1_07')
        end

        it 'should fail to detect if micro is not specified' do
          ENV['LBP_IBMJDK_VERSION'] = '1.7'
          expect { detected }.to raise_error(RuntimeError)
        end

        it 'should fail to detect if micro does not exist' do
          ENV['LBP_IBMJDK_VERSION'] = '1.7.2'
          expect { detected }.to raise_error(RuntimeError)
        end

        it 'should fail to detect if qualifier does not exist' do
          ENV['LBP_IBMJDK_VERSION'] = '1.7.1_107'
          expect { detected }.to raise_error(RuntimeError)
        end

      end # end of detect shared tests

    end
  end

end

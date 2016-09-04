# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
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
require 'liberty_buildpack/container/common_paths'

module LibertyBuildpack::Container

  describe CommonPaths do

    HEROKU_ENV_VAR = 'DYNO'.freeze

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    after do
      $stdout = STDOUT
      $stderr = STDERR
    end

    # Heroku
    context 'For a PaaS where the app root is the same as the container user home' do
      before do
        ENV[HEROKU_ENV_VAR] = 'dyno'
      end

      after(:each) do
        ENV[HEROKU_ENV_VAR] = nil
      end

      it 'should use the current dir as the app_dir value by default' do
        common_paths = CommonPaths.new

        expect(common_paths.instance_variable_get(:@relative_to_base)).to eq('.')
        expect(common_paths.relative_location).to eq('.')
      end

      # user home and app root are both the same, such as /home/dynouser is the default behavior
      [nil, '.'].each do |test_app_root|
        subject(:common_paths) { CommonPaths.new(test_app_root) }

        # standalone java container
        context 'with a container which executes at the root of the app dir' do
          it 'should default to the current working directory of the app root as a relative location' do
            expect(common_paths.relative_location).to eq('.')
            expect(common_paths.diagnostics_directory).to eq('./.buildpack-diagnostics')
          end

          it 'should return logs and dumps dir relative to the user root' do
            expect(common_paths.log_directory).to eq('./logs')
            expect(common_paths.dump_directory).to eq('./dumps')
          end
        end

        # Liberty container
        context 'with a container that adjusts the relative dir because it executes in a subdir of the app dir' do
          let(:new_relative_location) { 'liberty/usr/server/defaultServer' }

          before do
            common_paths.relative_location = new_relative_location
          end

          it 'should return the relative location of the container-provided path to the app root' do
            expect(common_paths.relative_location).to eq('../../../..')
            expect(common_paths.diagnostics_directory).to eq('../../../../.buildpack-diagnostics')
          end

          it 'should return logs and dumps dir relative to the user root adjusted with the relative location' do
            expect(common_paths.log_directory).to eq('../../../../logs')
            expect(common_paths.dump_directory).to eq('../../../../dumps')
          end
        end
      end # end of each test_app_root test
    end # end of Heroku

    # CFv2 - Do not stub Heroku.heroku? method to ensure the default behavior is tested
    context 'For a PaaS that provides an app root separate from the container user root' do

      it 'should use a relative path calculated from app as the app_dir value by default' do
        common_paths = CommonPaths.new

        expect(common_paths.instance_variable_get(:@relative_to_base)).to eq('./..')
        expect(common_paths.relative_location).to eq('.')
      end

      [nil, 'app', 'app/', './app', './app/', './app/another/..'].each do |test_app_root|
        # user root is /home/vcap while app root is /home/vcap/app
        subject(:common_paths) { CommonPaths.new(test_app_root) }

        # standalone java container
        context 'with a container which executes at the root of the app dir' do
          it 'should result in the default app root directory as a relative location' do
            expect(common_paths.relative_location).to eq('.')
            expect(common_paths.diagnostics_directory).to eq('./.buildpack-diagnostics')
          end

          it 'should return logs and dumps dir relative to the user root' do
            expect(common_paths.log_directory).to eq('./../logs')
            expect(common_paths.dump_directory).to eq('./../dumps')
          end
        end

        # Liberty container
        context 'with a container that adjusts the relative dir because it executes in a subdir of the app dir' do
          let(:new_relative_location) { 'liberty/usr/server/defaultServer' }

          before do
            common_paths.relative_location = new_relative_location
          end

          it 'should return the relative location of the container-provided path to the app root' do
            expect(common_paths.relative_location).to eq('../../../..')
            expect(common_paths.diagnostics_directory).to eq('../../../../.buildpack-diagnostics')
          end

          it 'should return logs and dumps dir relative to the user root adjusted with the relative location' do
            expect(common_paths.log_directory).to eq('../../../../../logs')
            expect(common_paths.dump_directory).to eq('../../../../../dumps')
          end
        end
      end # end of each test_app_root test
    end # end of CFv2 Context

    describe 'invalid paths' do
      INVALID_PATH_ERROR = 'relative_location provided to common_paths must be nonempty and without spaces'.freeze
      INVALID_RELATIVE_PATH_ERROR = 'paths provided to CommonPaths must be a relative, subdirectory, and a valid Pathname'.freeze

      ['', ' ', 'includes space'].each do |test_app_root|
        it 'should raise an error for invalid relative_location' do
          expect { CommonPaths.new(test_app_root) }.to raise_error(INVALID_PATH_ERROR)
        end
      end

      ['/', '/absolute/path', '../from/parent'].each do |test_app_root|
        it 'should raise an error for invalid relative_location' do
          expect { CommonPaths.new(test_app_root) }.to raise_error(INVALID_RELATIVE_PATH_ERROR)
        end
      end

      [nil, '', ' '].each do |test_relative_location|
        it 'should raise an error for invalid relative_location' do
          common_paths = CommonPaths.new
          expect { common_paths.relative_location = test_relative_location }.to raise_error(INVALID_PATH_ERROR)
        end
      end
    end # end of invalid paths tests

  end

end

# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013 the original author or authors.
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

require 'simplecov'

SimpleCov.start do
  add_filter 'spec'
end

require 'tmpdir'
require 'webmock/rspec'
# Ensure a logger exists for any class under test that needs one.
require 'fileutils'
require 'liberty_buildpack/diagnostics/common'
require 'liberty_buildpack/diagnostics/logger_factory'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.before(:all) do
    LibertyBuildpack::Diagnostics::LoggerFactory.send :close
    tmpdir = Dir.tmpdir
    diagnostics_directory = File.join(tmpdir, LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY)
    FileUtils.rm_rf diagnostics_directory
    raise 'Failed to create logger' if LibertyBuildpack::Diagnostics::LoggerFactory.create_logger(tmpdir).nil?
  end

  config.after(:all) do
    tmpdir = Dir.tmpdir
    diagnostics_directory = File.join(tmpdir, LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY)
    FileUtils.rm_rf diagnostics_directory
  end

  config.after(:suite) do
    LibertyBuildpack::Diagnostics::LoggerFactory.send :close
    FileUtils.rm_rf File.join(Dir.tmpdir, LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY)
  end
end

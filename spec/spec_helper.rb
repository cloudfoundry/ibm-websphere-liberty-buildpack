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

require 'simplecov'
require 'simplecov-rcov'
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start do
  add_filter 'spec'
end

require 'tmpdir'
require 'webmock/rspec'
require 'fileutils'
require 'liberty_buildpack/diagnostics/common'
require 'liberty_buildpack/diagnostics/logger_factory'

require 'liberty_buildpack/util/cache/yield_file_with_content'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
  config.filter_run :focus
  # Ensure a logger exists for any class under test that needs one.
  config.before(:all) do
    LibertyBuildpack::Diagnostics::LoggerFactory.send :close
    diagnostics_directory = LibertyBuildpack::Diagnostics.get_diagnostic_directory(Dir.tmpdir)
    FileUtils.rm_rf diagnostics_directory
    raise 'Failed to create logger' if LibertyBuildpack::Diagnostics::LoggerFactory.create_logger(Dir.tmpdir).nil?
  end

  config.after(:all) do
    LibertyBuildpack::Diagnostics::LoggerFactory.send :close
    diagnostics_directory = LibertyBuildpack::Diagnostics.get_diagnostic_directory(Dir.tmpdir)
    FileUtils.rm_rf diagnostics_directory
  end

end

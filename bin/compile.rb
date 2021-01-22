#!/usr/bin/env ruby
# frozen_string_literal: true

# IBM WebSphere Application Server Liberty Buildpack
# Copyright IBM Corp. 2017, 2019
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
$stdout.sync = true
$stderr.sync = true
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'liberty_buildpack/buildpack'
build_dir = ARGV[0]

LibertyBuildpack::Buildpack.initialize_env(ARGV[2]) unless ARGV[2].nil?

LibertyBuildpack::Buildpack.drive_buildpack_with_logger(build_dir, 'Compile failed with exception %s', &:compile)

#!/usr/bin/env ruby
# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright IBM Corp. 2013, 2017
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
if [[ "${CF_STACK:-}" == "cflinuxfs4" ]]; then
  `dirname $0`/install_ruby.sh
  RUBY_DIR="/tmp/ruby"
  export PATH="${RUBY_DIR}/bin:${PATH:-}"
  export LIBRARY_PATH="${RUBY_DIR}/lib:${LIBRARY_PATH:-}"
  export LD_LIBRARY_PATH="${RUBY_DIR}/lib:${LIBRARY_PATH:-}"
  export CPATH="${RUBY_DIR}/include:${CPATH:-}"
fi

$stdout.sync = true
$stderr.sync = true
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'liberty_buildpack/buildpack'

build_dir = ARGV[0]

puts LibertyBuildpack::Buildpack.drive_buildpack_with_logger(build_dir, 'Release failed with exception %s', &:release)

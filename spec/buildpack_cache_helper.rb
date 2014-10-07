# Encoding: utf-8
# Cloud Foundry Java Buildpack
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
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
require 'application_helper'
require 'fileutils'

shared_context 'buildpack_cache_helper' do
  include_context 'application_helper'

  previous_buildpack_cache = ENV['BUILDPACK_CACHE']

  let(:buildpack_cache_dir) { app_dir }

  let(:java_buildpack_cache_dir) { buildpack_cache_dir + 'java-buildpack' }

  before do
    FileUtils.mkdir_p java_buildpack_cache_dir
    ENV['BUILDPACK_CACHE'] = buildpack_cache_dir.to_s
  end

  after do
    ENV['BUILDPACK_CACHE'] = previous_buildpack_cache
  end

end

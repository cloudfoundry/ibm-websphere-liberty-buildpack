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
require 'yaml'

shared_context 'application_helper' do

  YAML::ENGINE.yamler = 'psych' if RUBY_VERSION == '1.9.2'

  let(:app_dir) { Pathname.new Dir.mktmpdir }

  previous_environment = ENV.to_hash

  let(:environment) do
    { 'test-key'      => 'test-value', 'VCAP_APPLICATION' => vcap_application.to_yaml,
      'VCAP_SERVICES' => vcap_services.to_yaml }
  end

  let(:vcap_application) { { 'application_name' => 'test-application-name' } }

  let(:vcap_services) do
    { 'test-service-n/a' => [{ 'name'        => 'test-service-name', 'label' => 'test-service-n/a',
                               'tags'        => ['test-service-tag'], 'plan' => 'test-plan',
                               'credentials' => { 'uri' => 'test-uri' } }] }
  end

  before do
    ENV.update environment
    FileUtils.mkdir_p app_dir
  end

  after do
    ENV.replace previous_environment
    FileUtils.rm_rf app_dir
  end

end

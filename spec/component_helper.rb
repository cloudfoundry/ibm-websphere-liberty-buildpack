# Encoding: utf-8
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
require 'console_helper'
require 'logging_helper'

shared_context 'component_helper' do
  include_context 'application_helper'
  include_context 'console_helper'
  include_context 'logging_helper'

  let(:component) { described_class.new context }

  let(:context) do |example|
    { app_dir:        app_dir,
      java_home:      example.metadata[:java_home],
      java_opts:      example.metadata[:java_opts],
      common_paths:   example.metadata[:common_paths],
      license_ids:    example.metadata[:license_ids],
      configuration:  example.metadata[:configuration],
      jvm_type:       example.metadata[:jvm_type],
      vcap_application: example.metadata[:vcap_application_context],
      vcap_services:  example.metadata[:vcap_services_context] }
  end

  let(:uri) { 'test-uri' }
  let(:version) { '0.0.0' }

end

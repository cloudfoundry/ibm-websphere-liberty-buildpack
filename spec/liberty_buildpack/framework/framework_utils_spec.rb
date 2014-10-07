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
require 'liberty_buildpack/framework/framework_utils'

module LibertyBuildpack::Framework

  describe FrameworkUtils do

    it 'should find in lib dir' do
      app_dir = 'spec/fixtures/framework_auto_reconfiguration_servlet_4'
      pattern = "#{app_dir}/**/spring-core*.jar"

      result = FrameworkUtils.find(app_dir, pattern)
      expect(result).to include(app_dir)
    end

    it 'should find in WEB-INF dir' do
      app_dir = 'spec/fixtures/framework_auto_reconfiguration_servlet_2'
      pattern = "#{app_dir}/**/spring-core*.jar"

      result = FrameworkUtils.find(app_dir, pattern)
      expect(result).to include(app_dir)
    end

    it 'should find in .ear and .war files' do
      app_dir = 'spec/fixtures/framework_auto_reconfiguration_servlet_5'

      result = FrameworkUtils.find(app_dir)
      expect(result).to include("#{app_dir}/spring_app.war")
      expect(result).to include("#{app_dir}/spring_app.ear")
    end

  end

end

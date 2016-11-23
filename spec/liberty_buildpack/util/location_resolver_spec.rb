# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2016 the original author or authors.
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

require 'liberty_buildpack/util'
require 'liberty_buildpack/util/location_resolver'
require 'logging_helper'

describe LibertyBuildpack::Util::LocationResolver do
  include_context 'logging_helper'

  it 'resolve built-in variables' do
    Dir.mktmpdir do |root|
      liberty_home = File.join(root, '.liberty')
      server_name = 'myServer'

      location_resolver = LibertyBuildpack::Util::LocationResolver.new(root, liberty_home, server_name)

      # single variable
      expect(location_resolver.absolute_path('${server.config.dir}/foo', liberty_home)).to eql("#{liberty_home}/usr/servers/#{server_name}/foo")
      # variable does not exist
      expect(location_resolver.absolute_path('${server.config.doesnotexist}/foo', liberty_home)).to eql("#{liberty_home}/${server.config.doesnotexist}/foo")
    end
  end

  it 'resolve environment in variables' do
    Dir.mktmpdir do |root|
      ENV['test.space'] = 'dev'
      ENV['test.profile'] = 'bluemix'

      liberty_home = File.join(root, '.liberty')
      server_name = 'myServer'

      location_resolver = LibertyBuildpack::Util::LocationResolver.new(root, liberty_home, server_name)

      # single variable
      expect(location_resolver.absolute_path('${env.test.space}/foo', liberty_home)).to eql("#{liberty_home}/dev/foo")
      # multiple variables with mixed case
      expect(location_resolver.absolute_path('${env.test.space}/foo/${ENV.test.profile}', liberty_home)).to eql("#{liberty_home}/dev/foo/bluemix")
      # variable does not exist
      expect(location_resolver.absolute_path('${env.test.doesnotexist}/foo', liberty_home)).to eql("#{liberty_home}/${env.test.doesnotexist}/foo")
    end
  end

end

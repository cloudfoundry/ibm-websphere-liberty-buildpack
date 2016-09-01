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

require 'spec_helper'
require 'open3'

describe 'release script', :integration do
  it 'should work with the liberty WEB-INF case' do
    Dir.mktmpdir do |root|
      FileUtils.cp_r 'spec/fixtures/container_liberty/.', root

      with_memory_limit('1G') do
        Open3.popen3("bin/release #{root}") do |_stdin, _stdout, _stderr, wait_thr|
          expect(wait_thr.value).to be_success
        end
      end
    end
  end

  it 'should work with the liberty zipped-up server case' do
    Dir.mktmpdir do |root|
      FileUtils.cp_r 'spec/fixtures/container_liberty_server/.', root

      with_memory_limit('1G') do
        Open3.popen3("bin/release #{root}") do |_stdin, _stdout, _stderr, wait_thr|
          expect(wait_thr.value).to be_success
        end
      end
    end
  end

  it 'should fail to release when no containers detect' do
    Dir.mktmpdir do |root|
      error = Open3.capture3("bin/release #{root}")[1]
      expect(error).to match(/No supported application type was detected/)
    end
  end

  def with_memory_limit(memory_limit)
    previous_value = ENV['MEMORY_LIMIT']
    begin
      ENV['MEMORY_LIMIT'] = memory_limit
      yield
    ensure
      ENV['MEMORY_LIMIT'] = previous_value
    end
  end
end

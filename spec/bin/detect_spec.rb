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

require 'spec_helper'
require 'open3'

describe 'detect script', :integration do

  LIBERTY_FOR_JAVA = 'Liberty for Java(TM) ('.freeze

  it 'should return zero if success on the liberty WEB-INF case' do
    Dir.mktmpdir do |root|
      FileUtils.cp_r 'spec/fixtures/container_liberty/.', root

      with_memory_limit('1G') do
        Open3.popen3("bin/detect #{root}") do |stdin, stdout, stderr, wait_thr|
          expect(stdout.read).to include(LIBERTY_FOR_JAVA + 'WAR')
          expect(wait_thr.value).to be_success
        end
      end

    end
  end

  it 'should return zero if success on the liberty zipped-up server case' do
    Dir.mktmpdir do |root|
      FileUtils.cp_r 'spec/fixtures/container_liberty_server/.', root

      with_memory_limit('1G') do
        Open3.popen3("bin/detect #{root}") do |stdin, stdout, stderr, wait_thr|
          expect(stdout.read).to include(LIBERTY_FOR_JAVA + 'SVR-PKG')
          expect(wait_thr.value).to be_success
        end
      end

    end
  end

  describe 'around Spring current directory test' do
    it 'should succeed when Spring is present and detect is applied in the current directory' do
      Dir.mktmpdir do |root|
        FileUtils.cp_r 'spec/fixtures/framework_auto_reconfiguration_servlet_2/.', root
        with_memory_limit('1G') do
          Open3.popen3("bin/detect #{root}") do |stdin, stdout, stderr, wait_thr|
            expect(stdout.read).to include(LIBERTY_FOR_JAVA + 'WAR')
            expect(wait_thr.value).to be_success
            expect(stderr.read).not_to include('undefined method')
          end
        end
      end
    end
  end

  it 'should fail to detect when no containers detect' do
    Dir.mktmpdir do |root|
      with_memory_limit('1G') do
        Open3.popen3("bin/detect #{root}") do |stdin, stdout, stderr, wait_thr|
          expect(stdout.read).to_not include(LIBERTY_FOR_JAVA)
          expect(wait_thr.value).to_not be_success
        end
      end
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

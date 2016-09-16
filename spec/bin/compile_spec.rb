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
require 'tmpdir'

describe 'compile script', :integration do

  before(:all) do
    @cache = File.join(Dir.tmpdir, 'compile_cache')
    FileUtils.rm_rf(@cache)
  end

  before(:each) do
    ENV.update('IBM_JVM_LICENSE' => 'L-PMAA-A3Z8P2', 'IBM_LIBERTY_LICENSE' => 'L-SWIS-ABKSXS', 'USER_AGENT' => 'RSpec-Test')
  end

  after(:each) do
    ENV.delete('USER_AGENT')
  end

  after(:all) do
    FileUtils.rm_rf(@cache)
    ENV.delete('IBM_JVM_LICENSE')
    ENV.delete('IBM_LIBERTY_LICENSE')
  end

  it 'should fail to compile when no containers detect' do
    Dir.mktmpdir do |root|
      error = Open3.capture3("bin/compile #{root} #{root}")[1]
      expect(error).to match(/No supported application type was detected/)
    end
  end

  it 'should work with the liberty WEB-INF case' do
    Dir.mktmpdir do |root|
      FileUtils.cp_r'spec/fixtures/container_liberty/.', root
      with_memory_limit('1G') do
        Open3.popen3("bin/compile #{root} #{@cache}") do |stdin, stdout, stderr, wait_thr|
          result = wait_thr.value
          if result != 0
            puts "stdout: #{stdout.read}"
            puts "stderr: #{stderr.read}"
          end
          expect(result).to be_success
        end # popen3
      end # with
    end # dir
  end # it

  it 'should also work with the zipped up server case' do
    Dir.mktmpdir do |root|
      FileUtils.cp_r 'spec/fixtures/container_liberty_server/.', root

      with_memory_limit('1G') do
        Open3.popen3("bin/compile #{root} #{@cache}") do |stdin, stdout, stderr, wait_thr|
          result = wait_thr.value
          if result != 0
            puts "stdout: #{stdout.read}"
            puts "stderr: #{stderr.read}"
          end
          expect(result).to be_success
        end # popen3
      end # with
    end # dir
  end # it

  it 'pass environment variable directory' do
    Dir.mktmpdir do |root|
      # environment variables passed as files
      ENV.delete('IBM_JVM_LICENSE')
      ENV.delete('IBM_LIBERTY_LICENSE')

      FileUtils.cp_r 'spec/fixtures/container_liberty_server/.', root

      with_memory_limit('1G') do
        Open3.popen3("bin/compile #{root} #{@cache} spec/fixtures/env") do |stdin, stdout, stderr, wait_thr|
          result = wait_thr.value
          if result != 0
            puts "stdout: #{stdout.read}"
            puts "stderr: #{stderr.read}"
          end
          expect(result).to be_success
        end # popen3
      end # with
    end # dir
  end # it

  it 'should also work with standalone spring-boot jar' do
    Dir.mktmpdir do |root|
      FileUtils.cp_r 'spec/fixtures/container_main_spring_boot_jar_launcher/.', root

      with_memory_limit('1G') do
        Open3.popen3("bin/compile #{root} #{@cache}") do |stdin, stdout, stderr, wait_thr|
          result = wait_thr.value
          if result != 0
            puts "stdout: #{stdout.read}"
            puts "stderr: #{stderr.read}"
          end
          expect(result).to be_success
        end # popen3
      end # with
    end # dir
  end # it

  def with_memory_limit(memory_limit)
    previous_value = ENV['MEMORY_LIMIT']
    begin
      ENV['MEMORY_LIMIT'] = memory_limit
      yield
    ensure
      ENV['MEMORY_LIMIT'] = previous_value
    end
  end
end # describe

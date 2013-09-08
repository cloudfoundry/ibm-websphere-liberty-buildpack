# Encoding: utf-8
# IBM Liberty Buildpack
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
require 'tmpdir'

describe 'create vars script', :integration do

  it 'should fail to execute when no path for the file is passed' do
    error = Open3.capture3('resources/liberty/create_vars.rb')[1]
    expect(error).to match(/Please pass me a place to store the xml output/)
  end

  it 'should execute to completion when a path for the file is passed' do
    Dir.mktmpdir do |root|
      Open3.popen3("resources/liberty/create_vars.rb #{File.expand_path root}/file_output.xml") do |stdin, stdout, stderr, wait_thr|
        expect(wait_thr.value).to be_success
      end
    end
  end

  it 'should put the port variable into play when it is present' do
    ENV['PORT'] = '3939'
    Dir.mktmpdir do |root|
      filename = File.join(File.expand_path(root), 'file_output.xml')
      Open3.popen3("resources/liberty/create_vars.rb #{filename}") do |stdin, stdout, stderr, wait_thr|
        expect(wait_thr.value).to be_success

        filecontents = File.read(filename)

        expect(filecontents).to include("<variable name='port' value='3939'/>")
      end
    end
  end

  it 'should put the two variables into play when they are present' do
    ENV['VCAP_CONSOLE_PORT'] = '32123'
    ENV['VCAP_CONSOLE_IP'] = '0.0.0.0'
    Dir.mktmpdir do |root|
      filename = File.join(File.expand_path(root), 'file_output.xml')
      Open3.popen3("resources/liberty/create_vars.rb #{filename}") do |stdin, stdout, stderr, wait_thr|
        expect(wait_thr.value).to be_success

        filecontents = File.read(filename)

        expect(filecontents).to include("<variable name='vcap_console_port' value='32123'/>")
        expect(filecontents).to include("<variable name='vcap_console_ip' value='0.0.0.0'/>")
      end
    end
  end

  it 'should correctly parse out elements from VCAP_APPLICATION and flatten them' do
    ENV['VCAP_APPLICATION'] = "{\"application_name\": \"myapp\", \"application_version\": \"23rion23roin23dnj32d\"}"
    Dir.mktmpdir do |root|
      filename = File.join(File.expand_path(root), 'file_output.xml')
      Open3.popen3("resources/liberty/create_vars.rb #{filename}") do |stdin, stdout, stderr, wait_thr|
        expect(wait_thr.value).to be_success

        filecontents = File.read(filename)

        expect(filecontents).to include("<variable name='application_name' value='myapp'/>")
        expect(filecontents).to include("<variable name='application_version' value='23rion23roin23dnj32d'/>")
      end
    end
  end

  it 'should skip vcap_services if they are set to empty' do
    ENV['VCAP_SERVICES'] = '{}'
    Dir.mktmpdir do |root|
      filename = File.join(File.expand_path(root), 'file_output.xml')
      Open3.popen3("resources/liberty/create_vars.rb #{filename}") do |stdin, stdout, stderr, wait_thr|
        expect(wait_thr.value).to be_success
      end
    end
  end

  it 'should correctly parse VCAP_SERVICES' do
    ENV['VCAP_SERVICES'] = "{\"mongodb-2.2\":[{\"name\":\"mongodb-3244e\",\"label\":\"mongodb-2.2\",\"plan\":\"free\",\"credentials\":{\"hostname\":\"9.37.193.66\",\"host\":\"9.37.193.66\",\"port\":25002,\"username\":\"44b438c9-862a-432c-a72a-6d3e10b258d5\",\"password\":\"972bb9d9-09d2-4c7b-9911-a3b26cad8277\",\"name\":\"68d3650d-72c7-48ad-8b20-b3ebd764b472\",\"db\":\"db\",\"url\":\"mongodb://44b438c9-862a-432c-a72a-6d3e10b258d5:972bb9d9-09d2-4c7b-9911-a3b26cad8277@9.37.193.66:25002/db\"}}],\"mysql-5.5\":[{\"name\":\"mysql-c987\",\"label\":\"mysql-5.5\",\"plan\":\"100\",\"credentials\":{\"name\":\"d8bce47767311498db98febffccae1f54\",\"hostname\":\"9.37.193.66\",\"host\":\"9.37.193.66\",\"port\":3307,\"user\":\"ucLIbd4sAP6Kf\",\"username\":\"ucLIbd4sAP6Kf\",\"password\":\"p5t2b4qpLzJ0j\"}}]}"
    Dir.mktmpdir do |root|
      filename = File.join(File.expand_path(root), 'file_output.xml')
      Open3.popen3("resources/liberty/create_vars.rb #{filename}") do |stdin, stdout, stderr, wait_thr|
        expect(wait_thr.value).to be_success
      end

      filecontents = File.read(filename)

      expect(filecontents).to include("<variable name='cloud.services.mongodb-3244e.plan' value='free'/>")
      expect(filecontents).to include("<variable name='cloud.services.mongodb-3244e.connection.hostname' value='9.37.193.66'/>")
    end
  end

end # describe

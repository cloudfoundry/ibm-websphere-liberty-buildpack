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

describe 'create vars script', :integration do

  it 'should fail to execute when no path for the file is passed' do
    error = Open3.capture3('resources/liberty/create_vars.rb')[1]
    expect(error).to match(/Please pass me a place to store the xml output/)
  end

  it 'should execute to completion when a path for the file is passed' do
    Dir.mktmpdir do |root|
      filename = File.join(root, 'runtime-vars.xml')
      File.open(filename, 'w') { |file| file.write('<server></server>') }
      Open3.popen3("resources/liberty/create_vars.rb #{filename}") do |stdin, stdout, stderr, wait_thr|
        expect(wait_thr.value).to be_success
      end
    end
  end

  it 'should put the port variable into play when it is present' do
    ENV['PORT'] = '3939'
    Dir.mktmpdir do |root|
      filename = File.join(root, 'runtime-vars.xml')
      File.open(filename, 'w') { |file| file.write('<server></server>') }
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
      filename = File.join(root, 'runtime-vars.xml')
      File.open(filename, 'w') { |file| file.write('<server></server>') }
      Open3.popen3("resources/liberty/create_vars.rb #{filename}") do |stdin, stdout, stderr, wait_thr|
        expect(wait_thr.value).to be_success

        filecontents = File.read(filename)

        expect(filecontents).to include("<variable name='vcap_console_port' value='32123'/>")
        expect(filecontents).to include("<variable name='vcap_console_ip' value='0.0.0.0'/>")
      end
    end
  end

  it 'should correctly parse out elements from VCAP_APPLICATION and flatten them' do
    ENV['VCAP_APPLICATION'] = '{"application_name": "myapp", "application_version": "23rion23roin23dnj32d"}'
    Dir.mktmpdir do |root|
      filename = File.join(root, 'runtime-vars.xml')
      File.open(filename, 'w') { |file| file.write('<server></server>') }
      Open3.popen3("resources/liberty/create_vars.rb #{filename}") do |stdin, stdout, stderr, wait_thr|
        expect(wait_thr.value).to be_success

        filecontents = File.read(filename)

        expect(filecontents).to include("<variable name='application_name' value='myapp'/>")
        expect(filecontents).to include("<variable name='application_version' value='23rion23roin23dnj32d'/>")
      end
    end
  end

end # describe

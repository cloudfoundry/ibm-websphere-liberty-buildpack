#!/usr/bin/env ruby
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

require 'fileutils'
require 'json'
require 'rexml/document'

def add_runtime_variable(element, name, value)
  unless name.nil? || value.nil?
    new_element = REXML::Element.new('variable', element)
    new_element.add_attribute('name', name.downcase)
      new_element.add_attribute('value', value)
  end
end

def add_variable(element, name)
    add_runtime_variable(element, name, ENV[name].to_s) unless ENV[name].nil?
end

def add_vcap_app_variable(element, name)
  unless ENV['VCAP_APPLICATION'].nil?
    json_app = JSON.parse(ENV['VCAP_APPLICATION'])
    add_runtime_variable(element, name, json_app[name])
  end
end

def log_directory
  if ENV['DYNO'].nil?
    return '../../../../../logs'
  else
    return '../../../../logs'
  end
end

raise 'Please pass me a place to store the xml output' if ARGV[0].nil?

filename = ARGV[0]
document = File.open(filename, 'r') { |file| REXML::Document.new(file) }

add_variable(document.root, 'PORT')
add_variable(document.root, 'HOME')
add_variable(document.root, 'VCAP_CONSOLE_PORT')
add_variable(document.root, 'VCAP_APP_PORT')
add_variable(document.root, 'VCAP_CONSOLE_IP')
add_vcap_app_variable(document.root, 'application_name')
add_vcap_app_variable(document.root, 'application_version')
add_vcap_app_variable(document.root, 'host')
add_vcap_app_variable(document.root, 'application_uris')
add_vcap_app_variable(document.root, 'start')
add_runtime_variable(document.root, 'application.log.dir', log_directory)

File.open(filename, 'w') { |file| document.write(file, 2) }


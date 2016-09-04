#!/usr/bin/env ruby
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

require 'fileutils'
require 'json'
require 'rexml/document'

def add_runtime_variable(element, name, value)
  unless name.nil? || value.nil?
    variables = element.root.elements.to_a("//variable[@name='#{name.downcase}']")
    value = value.is_a?(Array) ? value.join(', ') : value
    if variables.empty?
      variable = REXML::Element.new('variable', element)
      variable.add_attribute('name', name.downcase)
      variable.add_attribute('value', value)
    else
      variables.last.add_attribute('value', value)
    end
  end
end

def add_variable(element, name)
  add_runtime_variable(element, name, ENV[name].to_s) unless ENV[name].nil?
end

def add_vcap_app_variable(element, json_app, name)
  add_runtime_variable(element, name, json_app[name]) unless json_app[name].nil?
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
document = File.open(filename, 'r:utf-8') { |file| REXML::Document.new(file) }

add_variable(document.root, 'PORT')
add_variable(document.root, 'HOME')
add_variable(document.root, 'VCAP_CONSOLE_PORT')
add_variable(document.root, 'VCAP_APP_PORT')
add_variable(document.root, 'VCAP_CONSOLE_IP')

unless ENV['VCAP_APPLICATION'].nil?
  json_app = JSON.parse(ENV['VCAP_APPLICATION'])
  add_vcap_app_variable(document.root, json_app, 'application_name')
  add_vcap_app_variable(document.root, json_app, 'application_version')
  add_vcap_app_variable(document.root, json_app, 'host')
  add_vcap_app_variable(document.root, json_app, 'application_uris')
  add_vcap_app_variable(document.root, json_app, 'start')
end

add_runtime_variable(document.root, 'application.log.dir', log_directory)

formatter = REXML::Formatters::Pretty.new(2)
formatter.compact = true
File.open(filename, 'w:utf-8') { |file| formatter.write(document, file) }

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

def add_variable(element, name)
  unless ENV[name].nil?
    new_element = REXML::Element.new('variable', element)
    new_element.add_attribute('name', name.downcase)
    new_element.add_attribute('value', ENV[name].to_s)
  end
end

def add_vcap_app_variable(element, name)
  unless ENV['VCAP_APPLICATION'].nil?
    json_app = JSON.parse(ENV['VCAP_APPLICATION'])
    unless json_app[name].nil?
      new_element = REXML::Element.new('variable', element)
      new_element.add_attribute('name', name.downcase)
      new_element.add_attribute('value', json_app[name])
    end
  end
end

def parse_vcap_services(element, string)
  return if string.nil?
  return if string.eql? '{}'

  svcjson = JSON.parse(string)
  svcjson.keys.each do |service_type|
    this_service_type = svcjson[service_type]
    this_service_type.each do |instance|
      instance.keys.each do |property|
        if instance[property].class == String
          new_element = REXML::Element.new('variable', element)
          new_element.add_attribute('name', "cloud.services.#{instance['name']}.#{property}")
          new_element.add_attribute('value', instance[property])
        elsif instance[property].class == Hash
          instance[property].keys.each do |subproperty|
            new_element = REXML::Element.new('variable', element)
            new_element.add_attribute('name', "cloud.services.#{instance['name']}.connection.#{subproperty}")
            new_element.add_attribute('value', instance[property][subproperty])
          end # each subproperty
        end # if
      end # each property
    end # each instance
  end # each service_type
end # def

raise 'Please pass me a place to store the xml output' if ARGV[0].nil?

filename = ARGV[0]
document = REXML::Document.new('<server></server>')

add_variable(document.root, 'PORT')
add_variable(document.root, 'VCAP_CONSOLE_PORT')
add_variable(document.root, 'VCAP_APP_PORT')
add_variable(document.root, 'VCAP_CONSOLE_IP')
add_vcap_app_variable(document.root, 'application_name')
add_vcap_app_variable(document.root, 'application_version')
add_vcap_app_variable(document.root, 'host')
add_vcap_app_variable(document.root, 'application_uris')
add_vcap_app_variable(document.root, 'start')
parse_vcap_services(document.root, ENV['VCAP_SERVICES'])

File.open(filename, 'w') { |file| document.write(file) }


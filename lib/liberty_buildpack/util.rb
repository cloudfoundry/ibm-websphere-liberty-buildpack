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

require 'liberty_buildpack'

# A module encapsulating all of the utility code for the Java buildpack
module LibertyBuildpack::Util

  # Get env variables for a service you are filtering from the hash of VCAP_SERVICES
  #
  # @return [String] returns the env variables for the service
  def find_service(vcap_services, filter)
    return nil unless vcap_services

    service_types = vcap_services.keys.select { |key| key =~ filter }
    return nil if service_types.length > 1

    service = nil
    if service_types.length == 1
      service_instances = vcap_services[service_types[0]]
      return nil if service_instances.length != 1
      service = service_instances[0]
    else # user-provided service
      user_services = vcap_services['user-provided']
      if user_services
        filtered_user_services = user_services.select { |v| v['name'] =~ filter }
        return nil if filtered_user_services.length != 1
        service = filtered_user_services[0]
      end
    end

    service
  end

  # Get services as either hash or string and return as a string with
  # credentials info masked out as PRIVATE DATA HIDDEN string
  #
  # @return [String] returns masked vcap_services string
  def self.safe_vcap_services(vcap_services)
    vcap_services.to_s.gsub(/(\"credentials\".+?){.*?}/, '\\1["PRIVATE DATA HIDDEN"]')
  end

  # Get services as either array or a string of lines from runtime_vars.xml
  # and mask cloud.services.*.connection.* values out as PRIVATE DATA HIDDEN
  #
  # @return [String] returns masked runtime_vars.xml content
  def self.safe_credential_properties(property)
    property.to_s.gsub(/(<variable\s+name='cloud\.services\.[^']*\.connection\.[^']*'\s+value=').*?('\s*\/>)/, '\\1[PRIVATE DATA HIDDEN]\\2')
  end
end

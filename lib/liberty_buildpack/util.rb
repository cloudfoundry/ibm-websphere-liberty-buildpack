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
require 'liberty_buildpack/util/heroku'
require 'json'

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

  # Get services as either hash or string and return as the same object but
  # with credentials info masked out as PRIVATE DATA HIDDEN string
  #
  # @return [Object] returns object with credentials info masked out
  def self.safe_vcap_services(vcap_services)
    if vcap_services.class == String && !vcap_services.strip.empty?
      begin
        safe_hash = JSON.load(vcap_services)
      rescue JSON::ParserError
        return vcap_services
      end
    elsif vcap_services.class == Hash
      safe_hash = vcap_services.clone
    else
      return vcap_services
    end
    safe_hash.each { |type, data| safe_hash[type] = safe_service_data(data) }
    if vcap_services.class == String
      safe_hash.to_json
    else
      safe_hash
    end
  end

  # Get array of service instances and mask 'credential' entry in each
  # of them with PRIVATE DATA HIDDEN
  #
  # @return [Array] returns array of masked out instances
  def self.safe_service_data(vcap_service_data)
    return vcap_service_data if vcap_service_data.class != Array
    safe_array = []
    vcap_service_data.each do |instance|
      safe_instance = instance.clone
      if safe_instance.class == Hash && safe_instance.has_key?('credentials')
        safe_instance['credentials'] = ['PRIVATE DATA HIDDEN']
      end
      safe_array << safe_instance
    end
    safe_array
  end

  # Get services as either array or a string of lines from runtime_vars.xml
  # and mask cloud.services.*.connection.* values out as PRIVATE DATA HIDDEN
  #
  # @return [String] returns masked runtime_vars.xml content
  def self.safe_credential_properties(property)
    property.to_s.gsub(/(<variable\s+name='cloud\.services\.[^.]*\.connection\..*?'\s+value=').*?('\s*\/>)/, '\\1[PRIVATE DATA HIDDEN]\\2')
  end

  # Get copy of ENV as a hash and mask in place all Heroku specific
  # environment variables containing 'credentials' information
  #
  # @return [Hash] return env back with the data
  def self.safe_heroku_env!(env)
    env.each do |key, value|
      if key.end_with?(Heroku::URL_SUFFIX) || key.end_with?(Heroku::URI_SUFFIX)
        env[key] = '[PRIVATE DATA HIDDEN]'
      end
    end
  end

  # Determine the requested repository version based on the JVM environment variable (@jvm_type).
  #
  # At present, the usage of this method is limited to jre components. Usage may be expanded to other components in the future
  #
  # @param [Hash] config the configuration hash from the context passed to this object in the context. The hash must contain a 'version' => Hash
  #     and the version has must contain a value for the key of 'default'.
  # @param [String] jvm_type the contents of the JVM environment variable (passed in as the contexts @jvm_type attribute)
  def self.user_requested_version(config, jvm_type)
    default = config['version'][config['version']['default']]
    return default if jvm_type.nil?
    parts = jvm_type.split('-', 2)
    return default if parts.empty? || parts.size == 1
    requested = parts[1]
    version = config['version'][requested]
    if version.nil?
      LibertyBuildpack::Diagnostics::LoggerFactory.get_logger.debug("No mapping found for requested jre version #{requested}, using the default")
      return default
    end
    version
  end
end

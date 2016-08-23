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

require 'liberty_buildpack/util'
require 'liberty_buildpack/util/cache/application_cache'
require 'liberty_buildpack/util/format_duration'

module LibertyBuildpack::Util

  # Compares the provided license id with the id that is extracted from the license url.
  #
  # @param [String] license_uri the url of the license containing our license id
  # @param [String] license_id the license id provided by the user
  # @return [boolean] return true if the license id's match, false otherwise
  def self.check_license(license_uri, license_id)
    return true if license_uri.nil?

    # The below regex ignores white space and grabs anything between the first occurrence of "D/N:" and "<".
    LibertyBuildpack::Util::Cache::ApplicationCache.new.get(license_uri) do |file|
      scanned_license = file.read.force_encoding('ISO-8859-1').scan(/D\/N:\s*(.*?)\s*\</m)
      if scanned_license.empty?
        raise 'No D/N code found in the license file'
      else
        license = scanned_license.first.last
      end

      return license_id == license
    end
  end

end

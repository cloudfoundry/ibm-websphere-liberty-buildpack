# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright (c) 2013 the original author or authors.
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
require 'liberty_buildpack/util/application_cache'
require 'liberty_buildpack/util/format_duration'

module LibertyBuildpack::Util

  # Compares the provided license id with the id that is extracted from the license url.
  #
  # @param [String] url of the license to check against
  # @param [String] actual id provided by the user
  # @raise if the license url is nil
  # @return [boolean] return true if the license id's match, false otherwise
  def self.check_license(license_uri, license_id)
    raise 'The license URL has returned nil' if license_uri.nil?

    # The below regex ignores white space and grabs anything between the first occurrence of "D/N:" and "<".
    license = open(license_uri).read.scan(/D\/N:\s*(.*?)\s*\</m).last.first

    license_id == license ? true : false
  end

end
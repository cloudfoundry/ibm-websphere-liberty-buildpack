# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2015 the original author or authors.
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

require 'net/http'
require 'uri'

# The Net:HTTP library in Ruby 1.9.2 does not send SNI TLS extension. The extension maybe
# be required by certain web sites.
# This class extends the Net:HTTP class and sets the SNI extension on older Ruby runtime.
module LibertyBuildpack::Util

  # Provides SNI TLS work-around for Net::HTTP
  class HTTP < Net::HTTP

    def use_ssl?
      # Set SNI TLS extension on SSLSocket if using older Ruby
      if @use_ssl && RUBY_VERSION < '1.9.3' && !@socket.nil? && !@socket.io.nil?
        @socket.io.hostname = @address if @socket.io.respond_to? :hostname=
      end
      @use_ssl
    end

  end

end

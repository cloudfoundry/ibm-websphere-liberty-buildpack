# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
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

module LibertyBuildpack::Container
  # The class that contains the list of components that need to be unzipped or installed
  class InstallComponents
    attr_reader :zips, :esas

    def initialize
      # zips array. Each entry is an array of [url, directory]. The url is for anything that needs
      # to be unzipped (.tgz, .zip). The optional directory is the directory name where the
      # contents of the zip file will be unpacked under the app_dir directory.
      # This array is ordered by insert or arrival order.
      @zips = []
      # esas will also be contained in an array, but each array entry is an array of [url, string]. Again, ordering is important.
      @esas = []
      @pending = {}
    end

    #----------------------------------------------------------------------------------
    # Add a zip or tar file to the list of zips that need to be downloaded/unzipped to create Liberty
    #
    # @param url - the download url
    # @param directory - the optional directory to unzip/untar the contents into under the app_dir directory.
    #----------------------------------------------------------------------------------
    def add_zip(url, directory = nil)
      # deal with null url (user errors or repository issues) and avoid runtime failures
      return if url.nil? == true
      # if another service has already added the url to the list, ignore.
      return if @pending.key?(url)
      @zips.push([url, directory])
      @pending[url] = 1
    end

    #-----------------------------------------------------------------------------------
    # Add an esa to the list of esa's to install
    #
    # @param url - the non-null url used to download the esa.
    # @param options_string - the options string to pass to the featureManager when installing the esa. e.g '--when-file-exists=ignore --acceptLicense --to=icap'
    #-----------------------------------------------------------------------------------
    #
    def add_esa(url, options_string)
      # deal with null url (user errors or repository issues) and avoid runtime failures
      return if url.nil? == true
      # if another service has already added the url to the list, ignore.
      return if @pending.key?(url)
      @esas.push [url, options_string]
      @pending[url] = 1
    end
  end # class
end

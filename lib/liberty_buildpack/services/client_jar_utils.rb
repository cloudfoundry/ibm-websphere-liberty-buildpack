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
# limitations under the License
require 'liberty_buildpack/diagnostics/logger_factory'
module LibertyBuildpack::Services

  #-----------------------------------
  # A class of static utility methods related to client jars
  #----------------------------------
  class ClientJarUtils

    #---------------------------------------------------
    # Process the list of fully qualified jar file names to determine if a jar matching the specified criteria exists.
    #
    # @param files - an array containing the names of the jar files that are already installed.
    # @param reg_ex - the Regexp to use in the search
    # return true if the required jar is already installed, false otherwise.
    #--------------------------------------------------
    def self.jar_installed?(files, reg_ex)
      return false if files.length == 0
      # operate on the base names
      files.each do |file|
        base_name = File.basename(file)
        result = base_name.scan(reg_ex)
        return true if result.length > 0
      end
      false
    end

    #----------------------------------------------------
    # Process the list of installed driver jars, find those whose base name matches the search criteria and return the base names
    #
    # @param files - an array containing the available download urls
    # @param reg_ex - a Regexp to use in the search
    # return an array of all urls to download
    #----------------------------------------------------
    def self.get_jar_names(files, reg_ex)
      # operate on the base names
      jars = []
      files.each do |file|
        base_name = File.basename(file)
        # puts "get_jar_names, basename is #{base_name}"
        result = base_name.scan(reg_ex)
        jars.push(base_name) if result.length > 0
      end
      jars
    end

    #------------------------------------------------------------------------------------
    # a method to create a global (shared) library
    #
    # @param doc - the root element of the REXML::Document for server.xml
    # @param lib_id - the String specifying the library id of the library to create
    # @param fileset_id - the String specifying the fileset id of the (nested) fileset to create
    # @param lib_dir - the String specifying the directory where client driver jars are located
    # @param client_jars_string - the String specifying the jar names. Built this by calling the client_jar_string method of this class.
    # @param api_visibility [String] - the api visibility to set on the shared library.
    # return true (dirty) if the document has changed and needs to be saved. Should never return false.
    # @raise if a library or fileset with the specified id already exists.
    #------------------------------------------------------------------------------------
    def self.create_global_library(doc, lib_id, fileset_id, lib_dir, client_jars_string, api_visibility = nil)
      # verify that the library and fileset don't already exist
      libs = doc.elements.to_a("//library[@id='#{lib_id}']")
      raise "create_global_library: Library with id #{lib_id} already exists" if libs.size != 0
      filesets = doc.elements.to_a("//fileset[@id='#{fileset_id}']")
      raise "create_global_library: fileset with id #{fileset_id} already exists" if filesets.size != 0
      # puts "create_lib with lib id of #{lib_id} and fileset_id of #{fileset_id} and includes of #{@client_jars_string}"
      # create the library and fileset. Library gets created at global scope and fileset is nested within it.
      library = REXML::Element.new('library', doc.root)
      library.add_attribute('id', lib_id)
      library.add_attribute('apiTypeVisibility', api_visibility) if api_visibility.nil? == false
      fileset = REXML::Element.new('fileset', library)
      fileset.add_attribute('id', fileset_id)
      fileset.add_attribute('dir', lib_dir)
      fileset.add_attribute('includes', client_jars_string)
      true
    end

    #------------------------------------------------------------------------------------
    # Find and update the fileset for the specified client jars.
    #
    # @param [Element] doc - the root element of the REXML::Document for server.xml
    # @param [String] name - the name of the calling service, for serviceability.
    # @param [Array] library - the array containing the physical Elements that comprise the one logical Library
    # @param default_id - the default name of the fileset
    # @param [String] lib_dir - the directory where client driver jars are located
    # @param [String] client_jars_string - the jars names. Built this by calling the client_jar_string method of this class.
    # @raise [Exception] if a problem is detected.
    #------------------------------------------------------------------------------------
    def self.update_library(doc, name, library, default_id, lib_dir, client_jars_string)
      # check first for the default fileset. This search should succeed if the user has followed our documented conventions.
      default = doc.elements.to_a("//fileset[@id='#{default_id}']")
      unless default.empty?
        ClientJarUtils.update_default_fileset(default, lib_dir, client_jars_string)
        return
      end
      # Tolerate unexpected fileset ids. We could also add code here to tolerate files.
      filesets = ClientJarUtils.find_all_filests(doc, library)
      raise "no filesets found for service #{name}" if filesets.empty?
      updated = ClientJarUtils.update_fileset(filesets, lib_dir, client_jars_string)
      # If no fileset was found, we could throw an exception or we can insert a new fileset. DB2 is a degenerate condition. For DB2, the user should specify both the db2jcc4.jar
      # and the license jar, but in the BlueMix environment they can get away without specifying the license jar. In that case the update method will not find the fileset
      unless updated
        # insert the fileset in the last element so it overrides any fileset specified with the same id.
        fileset = REXML::Element.new('fileset', library[-1])
        fileset.add_attribute('dir', lib_dir)
        fileset.add_attribute('includes', client_jars_string)
      end
    end

    #-------------------------------------------
    # Return a client jars string
    #
    # @param jars - the array of jar names
    #------------------------------------------
    def self.client_jars_string(jars)
      return nil if jars.nil?
      # need to generate a single white-space separated string containing the driver jar names. Construct in sorted order
      # so we can do a simple "string compare" later on when looking to see if we need to update.
      sorted = jars.sort
      jar_string = nil
      sorted.each do |name|
        if jar_string.nil?
          jar_string = name
        else
          jar_string << ' ' << name
        end
      end
      jar_string
    end

    private

    #------------------------------------------------------------------------------------
    # a private worker method for update_library to that finds all filesets in the library.
    #
    # @param [Element] doc - the root element of the REXML::Document for server.xml
    # @param [Array] library - the array containing all the physical Elements that comprise the one logical library.
    # @return [Array] - an array containing all the fileset Elements in the library.
    #------------------------------------------------------------------------------------
    def self.find_all_filests(doc, library)
      filesets = []
      library.each do |lib|
        # check filesetRef first
        fileset_attribute = lib.attribute('filesetRef').value unless lib.attribute('filesetRef').nil?
        unless fileset_attribute.nil?
          by_ref = doc.elements.to_a("//fileset[@id='#{fileset_attribute}']")
          by_ref.each { |fs| filesets.push(fs) }
        end
        # check fileset elements
        fileset_elements = lib.get_elements('fileset')
        fileset_elements.each { |element| filesets.push(element) }
      end
      filesets
    end

    #-----------------------------------------------------------------------------------
    # find the fileset whose includes match the specified client_jar_string and update the dir attribute to lib_dir
    #
    # @param [Array] filesets - the array of fileset Elements in a library
    # @param [String] lib_dir - the directory where client jars are located
    # @param [String] client_jar_string - the client jars string used to identify the target fileset.
    #-----------------------------------------------------------------------------------
    def self.update_default_fileset(filesets, lib_dir, client_jar_string)
      filesets.each do |fileset|
        # it would be really odd to find a partitioned fileset, but handle. Delete the dir and includes attributes from all existing elements, then add them back into the last one.
        fileset.delete_attribute('dir')
        fileset.delete_attribute('includes')
      end
      filesets[-1].add_attribute('dir', lib_dir)
      filesets[-1].add_attribute('includes', client_jar_string)
    end

    #-----------------------------------------------------------------------------------
    # find the fileset whose includes match the specified client_jar_string and update the dir attribute to lib_dir
    #
    # @param [Array] filesets - the array of fileset Elements in a library
    # @param [String] lib_dir - the directory where client jars are located
    # @param [String] client_jar_string - the client jars string that is used to identify the target fileset.
    #-----------------------------------------------------------------------------------
    def self.update_fileset(filesets, lib_dir, client_jar_string)
      # Tolerate user error where they've included multiple filesets with the same include by updating all.
      updated = false
      filesets.each do |fileset|
        jar_string = fileset.attribute('includes').value unless fileset.attribute('includes').nil?
        # We need to find out if this fileset's include contains the same entries as the client_jar_string. client_jar_string is sorted, but the entry may not be.
        next if jar_string.nil?
        # the includes can either be comma-separated or whitespace-separated.
        if jar_string.include?(',')
          jars = jar_string.split(',')
        else
          jars = jar_string.split
        end
        next if jars.empty?
        sorted_jar_string = ClientJarUtils.client_jars_string(jars)
        next unless sorted_jar_string == client_jar_string
        # update the dir attribute, overwrite if it already exists.
        fileset.add_attribute('dir', lib_dir)
        updated = true
      end
      updated
    end
  end
end

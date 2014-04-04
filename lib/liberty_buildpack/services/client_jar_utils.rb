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
# limitations under the License
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
        puts "get_jar_names, basename is #{base_name}"
        result = base_name.scan(reg_ex)
        jars.push(base_name) if result.length > 0
      end
      jars
    end

    #------------------------------------------------------------------------------------
    # a method to create a global (shared) library
    #
    # @param doc - the REXML::Document for server.xml
    # @param lib_id - the String specifying the library id of the library to create
    # @param fileset_id - the String specifying the fileset id of the (nested) fileset to create
    # @param lib_dir - the String specifying the directory where client driver jars are located
    # @param client_jars_string - the String specifying the jar names. Built this by calling the client_jar_string method of this class.
    # return true (dirty) if the document has changed and needs to be saved. Should never return false.
    # @raise if a library or fileset with the specified id already exists.
    #------------------------------------------------------------------------------------
    def self.create_global_library(doc, lib_id, fileset_id, lib_dir, client_jars_string)
      # verify that the library and fileset don't already exist
      libs = doc.elements.to_a("//library[@id='#{lib_id}']")
      raise "create_global_library: Library with id #{lib_id} already exists" if libs.size != 0
      filesets = doc.elements.to_a("//fileset[@id='#{fileset_id}']")
      raise "create_global_library: fileset with id #{fileset_id} already exists" if filesets.size != 0
      # puts "create_lib with lib id of #{lib_id} and fileset_id of #{fileset_id} and includes of #{@client_jars_string}"
      # create the library and fileset. Library gets created at global scope and fileset is nested within it.
      library = REXML::Element.new('library', doc.root)
      library.add_attribute('id', lib_id)
      fileset = REXML::Element.new('fileset', library)
      fileset.add_attribute('id', fileset_id)
      fileset.add_attribute('dir', lib_dir)
      fileset.add_attribute('includes', client_jars_string)
      true
    end

    #------------------------------------------------------------------------------------
    # a method to that finds the specified fileset for the specified library and updates it as necessary.
    #
    # The method will ensure that only one instance of the shared library and fileset exist and that the library "contains" the fileset.
    # This may be direct containment (expected) or by-reference.
    #
    # @param doc - the REXML::Document for server.xml
    # @param library - the Element for the library
    # @param lib_id - the String specifying the library id
    # @param fileset_id - the String specifying the fileset
    # @param lib_dir - the String specifying the directory where client driver jars are located
    # @param client_jars_string - the String specifying the jar names. Built this by calling the client_jar_string method of this class.
    # return true if the fileset was changed (and document needs to be saved) else false.
    #------------------------------------------------------------------------------------
    def self.update_library(doc, library, lib_id, fileset_id, lib_dir, client_jars_string)
      # The library should exist and should be unique. Requirement on the caller to have verified this.
      # The library must contain the specified fileset by reference or by direct containment. We expect the library to contain a single fileset
      # but we will tolerate multiples (as long as names are unique)
      fileset_byref = ClientJarUtils.find_fileset_byref(doc, library, fileset_id)
      fileset = ClientJarUtils.find_fileset_element(library, fileset_id)
      raise "update_library: Fileset with id #{fileset_id} does not exist" if fileset_byref.nil? && fileset.nil?
      raise "update_library: Fileset with id #{fileset_id} has multiple instances " unless fileset_byref.nil? || fileset.nil?
      fileset ||= fileset_byref
      # The fileset dir needs to point to lib_dir and the includes needs to equal @client_jars_string
      dirty = false
      if fileset.attribute('dir').nil? || fileset.attribute('dir').value != lib_dir
        # puts "fileset #{fileset_id} dir attribute being updated"
        fileset.delete_attribute('dir')
        fileset.add_attribute('dir', lib_dir)
        dirty = true
      end
      if fileset.attribute('includes').nil? || fileset.attribute('includes').value != client_jars_string
        # puts "fileset #{fileset_id} includes attribute being updated"
        fileset.delete_attribute('includes')
        fileset.add_attribute('includes', client_jars_string)
        dirty = true
      end
      dirty
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
    # a private worker method for update_library to that finds the specified fileset by reference, if it exists.
    #
    # @param doc - the REXML::Document for server.xml
    # @param library - the Element for the library
    # @param fileset_id - the String specifying the fileset
    # return the single fileset, or null.
    # @raise if multiple filesets with the specified id exist or if the reference was found but the fileset does not exist.
    #------------------------------------------------------------------------------------
    def self.find_fileset_byref(doc, library, fileset_id)
      fileset = nil
      fileset_ref = library.attribute('filesetRef')
      if fileset_ref.nil? == false
        # returns a String of comma separated fileset ids
        # puts "Retrieved filesetRef #{fileset_ref.value}"
        fileset_ref.value.split(',').each do |name|
          name = name.strip
          # puts "processing filesetRef #{name}"
          if name == fileset_id
            raise "update_library: Fileset with id #{fileset_id} has multiple instances " unless fileset.nil?
            # Find the global fileset using the fileset id. Expect exactly one instance.
            filesets = doc.elements.to_a("//fileset[@id='#{fileset_id}']")
            raise "update_library: Fileset with id #{fileset_id} does not exist" if filesets.size == 0
            raise "update_library: Fileset with id #{fileset_id} has multiple instances " if filesets.size > 1
            fileset = filesets[0]
          end
        end
      end
      fileset
    end

    #------------------------------------------------------------------------------------
    # a private worker method for update_library to that finds the specified fileset by containment, if it exists.
    #
    # @param library - the Element for the library
    # @param fileset_id - the String specifying the fileset
    # return the fileset, if found, else null.
    # @raise if multiple filesets with the specified id exist.
    #------------------------------------------------------------------------------------
    def self.find_fileset_element(library, fileset_id)
      fileset = nil
      fileset_elements = library.get_elements('fileset')
      fileset_elements.each do |element|
        element_id = element.attribute('id')
        if element_id.nil? == false && element_id.value == fileset_id
          raise "update_library: Fileset with id #{fileset_id} has multiple instances " unless fileset.nil?
          fileset = element
        end
      end
      fileset
    end

  end
end

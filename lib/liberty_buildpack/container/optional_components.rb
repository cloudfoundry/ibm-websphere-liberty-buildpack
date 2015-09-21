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
  # Encapsulates the mapping from optional Liberty Bluemix component download
  # names to feature names, and to xpath expressions that will match if any of
  # the features are present in a server.xml feature element.
  #
  # The component names are used in the component_index.yml file pointed to by
  # the index.yml file (except when the index.yml points directly to an
  # all-in-one Liberty download). The index.yml file is pointed to by the
  # buildpack's liberty.yml file.

  class OptionalComponents

    private

      CONFIG_FILE = '../../../config/liberty.yml'.freeze

      def self.initialize
        config = YAML.load_file(File.expand_path(CONFIG_FILE, File.dirname(__FILE__)))
        @@configuration = config['component_feature_map'] || {}
      end

      # Return an xpath string of the form,
      # "/server/featureManager/feature[. = 'x' or . = 'y']/node()"
      def self.feature_names_to_feature_xpath(feature_names)
        if feature_names.nil? || feature_names.empty?
          nil
        else
          "/server/featureManager/feature[. = '" << feature_names.join("' or . = '") << "']/node()"
        end
      end

      initialize

    public

      # ---------------------------------------------------------------
      # Get a list of Liberty features that given component provides.
      #
      # @param component_name - The component name.
      # @return An array of feature names.
      #----------------------------------------------------------------
      def self.feature_names(component_name)
        @@configuration[component_name]
      end

      # ---------------------------------------------------------------
      # Get an XPath expression string that may be used query against
      # the contents of a server.xml file to select any of the features
      # that a given component provides.
      # A non-empty result indicates that the server requires one or
      # more features that the component provides.
      #
      # @param component_name - The component name.
      # @return An XPath expression string.
      def self.feature_xpath(component_name)
        feature_names_to_feature_xpath(feature_names(component_name))
      end

  end

end

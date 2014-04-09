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

module LibertyBuildpack::Container
  # Encapsulates the mapping from optional Liberty Bluemix component download
  # names to feature names, and to xpath expressions that will match if any of
  # the features are present in a server.xml feature element.
  #
  # The component names are used in the component_index.yml file pointed to by
  # the index.yml file (except when the index.yml points directly to an
  # all-in-one Liberty download). The index.yml file is pointed to by the
  # buildpack's liberty.yml file.
  #
  # The liberty_core, icap_ext and appstate components are not optional.

  class OptionalComponents

    private

      # Return an xpath string of the form,
      # "/server/featureManager[feature = ('x') or feature = ('y')]"
      def self.feature_names_to_feature_xpath(feature_names)
        xpath = ''
        feature_names.each do
          |feature_name|
          xpath << (xpath.empty? ? "/server/featureManager[feature = ('#{feature_name}')" : " or feature = ('#{feature_name}')")
        end
        xpath << ']'
      end

    public

      # A map of Liberty Bluemix component name to an array of feature names
      # that the component provides.
      COMPONENT_NAME_TO_FEATURE_NAMES = {
        'liberty_ext' => ['jaxb-2.2', 'jaxws-2.2', 'jmsMdb-3.1', 'mongodb-2.0', 'wasJmsClient-1.1', 'wasJmsSecurity-1.0', 'wasJmsServer-1.0', 'wmqJmsClient-1.1', 'wsSecurity-1.1'],
      }.freeze

      # A map of Liberty Bluemix component name to an XPath expression string
      # that may be used query against the contents of a server.xml file to
      # select any of the features that the component provides. Thus a non-empty
      # result indicates that the server requires one or more features that the
      # component provides.
      COMPONENT_NAME_TO_FEATURE_XPATH = {
        'liberty_ext' => feature_names_to_feature_xpath(COMPONENT_NAME_TO_FEATURE_NAMES['liberty_ext']),
      }.freeze

  end

end
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

require 'liberty_buildpack'
require 'liberty_buildpack/container'
require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/util/xml_utils'
require 'rexml/document'
require 'rexml/xpath'

module LibertyBuildpack::Container

  # A class that encapsulates the interactions with Liberty's festureManager
  # to install features listed in a Liberty server.xml file. featureManager
  # obtains any missing features from the Liberty Repository.
  class FeatureManager

    public

      # constructor, note that java_home is relative to app_dir, and
      # configuration holds the parsed contents of liberty.yml. Expect the
      # given parameters are not nil, this should be the case as they are
      # passed-in from the liberty container code which also uses them.
      def initialize(app_dir, java_home, configuration)
        @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger

        @logger.debug("entry (#{app_dir}, #{java_home}, #{configuration}")
        @app_dir = app_dir
        @java_home = java_home # relative to app_dir
        @configuration = configuration
        @repository_description_properties_file = File.join(app_dir, '.repository.description.properties')
        @logger.debug("exit #{self}")
      end

      # convenience method for liberty container to use that returns true if
      # feature manager is enabled via configuration in liberty.yml, and false
      # otherwise (allows the container to switch between feature manager
      # downloads and other mechanisms, delete once container no longer needs
      # this).
      def self.enabled?(configuration)
        logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
        logger.debug('entry')
        enabled = FeatureManager.use_liberty_repository?(configuration)
        logger.debug("exit (#{enabled})")
        enabled
      end

      # download and install any features configured in server.xml that are not
      # already present in the liberty server by invoking liberty's
      # featureManager with the list of all features, and letting it determine
      # the missing features and then download these from the liberty feature
      # repository.
      def download_and_install_features(server_xml, liberty_home)
        @logger.debug('entry')
        if use_liberty_repository?
          features = get_features(server_xml)
          jvm_args = get_jvm_args
          cmd = File.join(liberty_home, 'bin', 'featureManager')
          script_string = "JAVA_HOME=\"#{@app_dir}/#{@java_home}\" JVM_ARGS=#{jvm_args} #{cmd} install --acceptLicense #{features} --when-file-exists=replace"

          @logger.debug("script invocation string is #{script_string}")
          output = `#{script_string}`
          # if ($CHILD_STATUS.to_i == 0) doesn't seem to work, as $CHILD_STATUS is
          # nil, so parse output for known message codes.
          if output.include?(FEATURES_ALREADY_PRESENT_MSG_CODE)
            @logger.debug("no extra features to install, output is #{output}")
          elsif output.include?(FEATURES_INSTALLED_MSG_CODE)
            @logger.debug("installed required features, output is #{output}")
          else
            @logger.debug("could not install required features, output is #{output}")
            raise "could not install required features, output is #{output}"
          end
        end
        @logger.debug('exit')
      end

      #-------------------------------
      # Remove incompatible versions of the same feature from server.xml.
      # For example, if both servlet-3.0 and servlet-3.1 are specified in featureManager, remove servlet-3.0
      #
      # @param doc - the REXML::Document for server.xml
      #-------------------------------
      def self.filter_conflicting_features(doc)
        features = get_features_in_server_xml(doc.root)
        to_remove = find_conflicting_features(features)
        remove_features_from_server_xml(doc.root, to_remove)
      end

    private

      FEATURES_ALREADY_PRESENT_MSG_CODE = 'CWWKF1216I'.freeze
      FEATURES_INSTALLED_MSG_CODE       = 'CWWKF1017I'.freeze
      CONFLICTING_FEATURES = { 'beanValidation-1.1' => 'beanValidation-1.0', 'ejbLite-3.2' => 'ejbLite-3.1', 'jaxrs-2.0' => 'jaxrs-1.1', 'jdbc-4.1' => 'jdbc-4.0',
        'jms-2.0' => 'jms-1.1', 'jmsMdb-3.2' => 'jmsMdb-3.1', 'jpa-2.1' => 'jpa-2.0', 'mdb-3.2' => 'mdb-3.1', 'servlet-3.1' => 'servlet-3.0',
        'wasJmsClient-2.0' => 'wasJmsClient-1.1', 'websocket-1.0' => 'servlet-3.0' }.freeze

      # common code used by internal instance method use_liberty_repository? and
      # public class method enabled?
      # true is returned if the correct property is set to true in the given
      # configuration hash, and false if it is set to false, or set to some
      # other value, or not present.
      def self.use_liberty_repository?(configuration)
        use_liberty_repository = false
        liberty_repository_properties = configuration['liberty_repository_properties']
        unless liberty_repository_properties.nil?
          use_liberty_repository = liberty_repository_properties['useRepository']
          use_liberty_repository = false unless use_liberty_repository == true
        end
        use_liberty_repository
      end

      # return true if liberty.yml indicates that we should use the liberty
      # feature repository to install any missing liberty server features, and
      # false otherwise. To enable use of the repository, liberty.yml should
      # contain,
      #   liberty_repository_properties:
      #    useRepository: true
      # if this property is missing or not set to 'true', the repository should
      # not be used.
      def use_liberty_repository?
        @logger.debug('entry')
        use_liberty_repository = FeatureManager.use_liberty_repository?(@configuration)
        @logger.debug("exit (#{use_liberty_repository})")
        use_liberty_repository
      end

      # return true if liberty.yml indicates that we should use the liberty
      # feature repository to install any missing liberty server features *and*
      # if a properties file should be used to configure the connection to the
      # repository; false is returned otherwise. To enable this kind of usage,
      # liberty.yml should contain,
      #   liberty_repository_properties:
      #    useRepository: true
      #    <further properties>
      # If no properties are present other than useRepository, and if
      # useRepository is set to true, this method will return false (and
      # subsequent code should have determined that the repository should be
      # used by calling useLiberty_repository? and use the default repository by
      # invoking featureManager without a properties file). If further
      # properties are present, a file will be written containing these
      # properties in the format key=value (rather than key: value), and true
      # will be returned.
      def use_liberty_repository_with_properties_file?
        @logger.debug('entry')
        use_liberty_repository_with_properties_file = false
        liberty_repository_properties = @configuration['liberty_repository_properties']
        if use_liberty_repository? && liberty_repository_properties.size > 1
          @logger.debug("liberty repository properties are #{liberty_repository_properties}")
          File.open(@repository_description_properties_file, 'w') do |file|
            liberty_repository_properties.each do |key, value|
              file.puts "#{key}=#{value}" unless key == 'useRepository'
            end
          end
          use_liberty_repository_with_properties_file = true
        end
        @logger.debug("exit (#{use_liberty_repository_with_properties_file})")
        use_liberty_repository_with_properties_file
      end

      # parse the given server.xml to find all features required and return a
      # comma-separated list of these. User features are excluded by looking for
      # features that do not contain a colon (user features specify a "product
      # extension" location before the colon that indicates the location of the
      # feature on disk, the default is to specify "usr").
      def get_features(server_xml)
        @logger.debug('entry')
        server_xml_doc = LibertyBuildpack::Util::XmlUtils.read_xml_file(server_xml)
        features = REXML::XPath.match(server_xml_doc, '/server/featureManager/feature/text()[not(contains(., ":"))]')
        features = features.join(',')
        @logger.debug("exit (#{features})")
        features
      end

      # figure out if a repository properties file is to be used to indicate the
      # liberty feature repository location (else we'll just use the built-in
      # Liberty defaults), and if so, return the jvm args that are required to
      # pass the location of this file to Liberty (if not, return the empty
      # string).
      def get_jvm_args
        @logger.debug('entry')
        if use_liberty_repository_with_properties_file?
          jvm_args = "-Drepository.description.url=\"file://#{@repository_description_properties_file}\""
        else
          jvm_args = ''
        end
        @logger.debug("exit (#{jvm_args})")
        jvm_args
      end

      #-------------------------------
      # Return a Set containing the names of all features specified in server.xml.
      #
      # @param doc - the REXML::Document for server.xml
      #-------------------------------
      def self.get_features_in_server_xml(doc)
        # Get the featureManager element. Assume there may be multiples
        managers = doc.elements.to_a('//featureManager')
        features = Set.new
        managers.each do |manager|
          elements = manager.get_elements('feature')
          elements.each do |element|
            features.add(element.text)
          end
        end
        features
      end

      #-------------------------------
      # Return a Set containing the names of all conflicting features that need to be removed from featureManager.
      #
      # @param features - a Set containing the names of features to be removed.
      #-------------------------------
      def self.find_conflicting_features(features)
        conflicts = Set.new
        features.each do |feature|
          conflict = CONFLICTING_FEATURES[feature]
          unless conflict.nil?
            puts "removing feature #{conflict} from server.xml as it conflicts with feature #{feature}"
            conflicts.add(conflict)
          end
        end
        conflicts
      end

      #-------------------------------
      # Remove all instances of the specified features from server.xml.
      #
      # @param doc - the REXML::Document for server.xml
      # @param to_remove - a Set containing the names of the features to remove.
      #-------------------------------
      def self.remove_features_from_server_xml(doc, to_remove)
        # Get the featureManager element. Assume there may be multiples
        managers = doc.elements.to_a('//featureManager')
        managers.each do |manager|
          elements = manager.get_elements('feature')
          elements.each do |element|
            manager.delete_element(element) if to_remove.include?(element.text)
          end
        end
      end

  end # class

end # module

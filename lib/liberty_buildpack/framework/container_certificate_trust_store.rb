# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

require 'liberty_buildpack/framework'
require 'liberty_buildpack/util/dash_case'
require 'liberty_buildpack/util/format_duration'
require 'fileutils'
require 'open3'
require 'shellwords'
require 'tempfile'

module LibertyBuildpack::Framework

  # Encapsulates the functionality for contributing container-based certificates to an application.
  class ContainerCertificateTrustStore

    # Creates an instance, passing in a context of information available to the component
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [Hash] :configuration the properties provided by the user
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    def initialize(context = {})
      @configuration = context[:configuration]
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
    end

    # If the component should be used when staging an application
    #
    # @return [Array<String>, String, nil] If the component should be used when staging the application, a +String+ or
    #                                      an +Array<String>+ that uniquely identifies the component (e.g.
    #                                      +open_jdk=1.7.0_40+).  Otherwise, +nil+.
    def detect
      supports_local_certificates? ? id(certificates.length) : nil
    end

    # Modifies the application's file system.  The component is expected to transform the application's file system in
    # whatever way is necessary (e.g. downloading files or creating symbolic links) to support the function of the
    # component.  Status output written to +STDOUT+ is expected as part of this invocation.
    #
    # @return [Void]
    def compile
      puts '-----> Creating TrustStore with container certificates'

      resolved_certificates = certificates
      with_timing(caption(resolved_certificates)) do
        unless use_jvm_trust_store?
          FileUtils.mkdir_p File.join(@app_dir, NEW_TRUST_STORE_DIRECTORY)
        end
        resolved_certificates.each_with_index { |certificate, index| add_certificate certificate, index }
      end
    end

    # Modifies the application's runtime configuration. The component is expected to transform members of the
    # +context+ # (e.g. +@java_home+, +@java_opts+, etc.) in whatever way is necessary to support the function of the
    # component.
    #
    # Container components are also expected to create the command required to run the application.  These components
    # are expected to read the +context+ values and take them into account when creating the command.
    #
    # @return [void, String] components other than containers and JREs are not expected to return any value.
    #                        Container and JRE components are expected to return a command required to run the
    #                        application.
    def release
      unless use_jvm_trust_store?
        # Hardcoded truststore location since @app_dir changes from staging to runtime and the java opts are set on staging.
        @java_opts << "-Djavax.net.ssl.trustStore=/home/vcap/app/#{NEW_TRUST_STORE_DIRECTORY}#{NEW_TRUST_STORE_FILE}"
        @java_opts << "-Djavax.net.ssl.trustStorePassword=#{password}"
      end
    end

    private

    CA_CERTIFICATES = Pathname.new('/etc/ssl/certs/ca-certificates.crt').freeze

    LOCAL_CERTS_ENABLED = 'enabled'.freeze

    USE_JVM_TRUST_STORE = 'jvm_trust_store'.freeze

    NEW_TRUST_STORE_DIRECTORY = '.container_certificate_trust_store/'.freeze

    NEW_TRUST_STORE_FILE = 'truststore.jks'.freeze

    private_constant :CA_CERTIFICATES

    # Wrap the execution of a block with timing information
    #
    # @param [String] caption the caption to print when timing starts
    # @return [Void]
    def with_timing(caption)
      start_time = Time.now
      print caption.to_s
      yield
      puts "(#{(Time.now - start_time).duration})"
    end

    def add_certificate(certificate, index)
      file = write_certificate certificate
      shell "#{keytool} -importcert -noprompt -keystore #{trust_store} -storepass #{password} -file #{file.to_path} -alias certificate-#{index}"
    end

    def ca_certificates
      CA_CERTIFICATES
    end

    def caption(resolved_certificates)
      "Adding #{resolved_certificates.count} certificates to #{trust_store}"
    end

    def certificates
      certificates = []

      certificate = nil
      ca_certificates.each_line do |line|
        if line =~ /BEGIN CERTIFICATE/
          certificate = line
        elsif line =~ /END CERTIFICATE/
          certificate += line
          certificates << certificate
          certificate = nil
        elsif !certificate.nil?
          certificate += line
        end
      end

      certificates
    end

    def id(count)
      "#{self.class.to_s.dash_case}=#{count}"
    end

    def keytool
      File.join(@app_dir, @java_home, '/jre/bin/keytool')
    end

    def password
      if use_jvm_trust_store?
        'changeit'
      else
        'java-buildpack-trust-store-password'
      end
    end

    def supports_configuration?
      !@configuration.nil? && @configuration[LOCAL_CERTS_ENABLED]
    end

    def supports_file?
      ca_certificates.exist?
    end

    def supports_local_certificates?
      supports_configuration? && supports_file?
    end

    def use_jvm_trust_store?
      @configuration[USE_JVM_TRUST_STORE] unless @configuration.nil?
    end

    def trust_store
      if use_jvm_trust_store?
        File.join(@app_dir, @java_home, '/jre/lib/security/cacerts')
      else
        File.join(@app_dir, NEW_TRUST_STORE_DIRECTORY, NEW_TRUST_STORE_FILE)
      end
    end

    def write_certificate(certificate)
      file = Tempfile.new('certificate-')
      file.write(certificate)
      file.fsync
      file
    end

    # A +system()+-like command that ensure that the execution fails if the command returns a non-zero exit code
    #
    # @param [Object] args The command to run
    # @return [Void]
    def shell(*args)
      Open3.popen3(*args) do |_stdin, stdout, stderr, wait_thr|
        if wait_thr.value != 0
          puts "\nCommand '#{args.join ' '}' has failed"
          puts "STDOUT: #{stdout.gets nil}"
          puts "STDERR: #{stderr.gets nil}"

          raise
        end
      end
    end

  end

end

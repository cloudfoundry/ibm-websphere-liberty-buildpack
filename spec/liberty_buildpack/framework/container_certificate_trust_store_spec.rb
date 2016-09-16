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

require 'spec_helper'
require 'component_helper'
require 'liberty_buildpack/framework/container_certificate_trust_store'

describe LibertyBuildpack::Framework::ContainerCertificateTrustStore do
  include_context 'component_helper'

  let(:ca_certificates) { Pathname.new('spec/fixtures/ca-certificates.crt') }

  it 'detects with ca-certificates file', configuration: { 'enabled' => 'true' } do
    allow(component).to receive(:ca_certificates).and_return(ca_certificates)

    expect(component.detect).to eq('container-certificate-trust-store=3')
  end

  it 'detects with ca-certificates file', configuration: { 'enabled' => 'true' } do
    allow(component).to receive(:ca_certificates).and_return(ca_certificates)

    expect(component.detect).to eq('container-certificate-trust-store=3')
  end

  it 'does not detect without ca-certificates file' do
    allow(component).to receive(:ca_certificates).and_return(Pathname.new('spec/fixtures/ca-certificates-no-exist.crt'))

    expect(component.detect).to be_nil
  end

  it 'does not detect when disabled and trust_store set', configuration: { 'enabled' => false } do
    allow(component).to receive(:ca_certificates).and_return(ca_certificates)

    expect(component.detect).to be_nil
  end

  it 'detects with ca-certificates file when trust_store is set', configuration: { 'enabled' => true } do
    allow(component).to receive(:ca_certificates).and_return(ca_certificates)

    expect(component.detect).to eq('container-certificate-trust-store=3')
  end

  it 'creates truststore', java_home: '/my/java_home', configuration: { 'enabled' => true, 'jvm_trust_store' => false } do
    app_dir = component.instance_variable_get('@app_dir')

    allow(component).to receive(:ca_certificates).and_return(ca_certificates)
    allow(component).to receive(:write_certificate).and_return(Pathname.new('/certificate-0'),
                                                               Pathname.new('/certificate-1'),
                                                               Pathname.new('/certificate-2'))
    allow(component).to receive(:shell).with("#{app_dir}/my/java_home/jre/bin/keytool -importcert -noprompt -keystore #{app_dir}/.container_certificate_trust_store/truststore.jks -storepass java-buildpack-trust-store-password -file /certificate-0 -alias certificate-0")
    allow(component).to receive(:shell).with("#{app_dir}/my/java_home/jre/bin/keytool -importcert -noprompt -keystore #{app_dir}/.container_certificate_trust_store/truststore.jks -storepass java-buildpack-trust-store-password -file /certificate-1 -alias certificate-1")
    allow(component).to receive(:shell).with("#{app_dir}/my/java_home/jre/bin/keytool -importcert -noprompt -keystore #{app_dir}/.container_certificate_trust_store/truststore.jks -storepass java-buildpack-trust-store-password -file /certificate-2 -alias certificate-2")

    component.compile
  end

  it 'replaces jvm trustStore with system cert', java_home: '/my/java_home', configuration: { 'enabled' => true, 'jvm_trust_store' => true } do
    app_dir = component.instance_variable_get('@app_dir')

    allow(component).to receive(:ca_certificates).and_return(ca_certificates)
    allow(component).to receive(:write_certificate).and_return(Pathname.new('/certificate-0'),
                                                               Pathname.new('/certificate-1'),
                                                               Pathname.new('/certificate-2'))
    allow(component).to receive(:shell).with("#{app_dir}/my/java_home/jre/bin/keytool -importcert -noprompt -keystore #{app_dir}/my/java_home/jre/lib/security/cacerts -storepass changeit -file /certificate-0 -alias certificate-0")
    allow(component).to receive(:shell).with("#{app_dir}/my/java_home/jre/bin/keytool -importcert -noprompt -keystore #{app_dir}/my/java_home/jre/lib/security/cacerts -storepass changeit -file /certificate-1 -alias certificate-1")
    allow(component).to receive(:shell).with("#{app_dir}/my/java_home/jre/bin/keytool -importcert -noprompt -keystore #{app_dir}/my/java_home/jre/lib/security/cacerts -storepass changeit -file /certificate-2 -alias certificate-2")

    component.compile
  end

  it 'adds truststore properties', java_opts: [] do
    component.release
    java_opts = component.instance_variable_get('@java_opts')

    expect(java_opts).to include('-Djavax.net.ssl.trustStore=/home/vcap/app/.container_certificate_trust_store/truststore.jks')
    expect(java_opts).to include('-Djavax.net.ssl.trustStorePassword=java-buildpack-trust-store-password')
  end

end

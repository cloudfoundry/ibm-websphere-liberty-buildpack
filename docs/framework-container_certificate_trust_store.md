IBM WebSphere Application Server Liberty Buildpack
Copyright IBM Corp. 2016

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
     http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

# Container Certificate Trust Store Framework
The Container Certificate Trust Store Framework contributes a Java `KeyStore` containing the certificates trusted by the operating system in the container to the application at rutime.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>/etc/ssl/certs/ca-certificates.crt</tt> file and <tt>enabled</tt> set in the <tt>config/container_certificate_trust_store.yml</tt> file</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>container-certificate-trust-store=&lt;number-of-certificates&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by creating or modifying the [`config/containercertificatetruststore.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `enabled` | Whether to enable the trust store
| `jvm_trust_store` | Whether to use the JVM trust store or not

[`config/containercertificatetruststore.yml`]: ../config/containercertificatetruststore.yml
[Configuration and Extension]: ../README.md#configuration-and-extension

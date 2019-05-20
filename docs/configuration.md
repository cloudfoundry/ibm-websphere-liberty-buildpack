IBM WebSphere Application Server Liberty Buildpack
Copyright IBM Corp. 2015

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
     http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Configuration
=============

The buildpack configuration can be overridden with an environment variable matching the [configuration file](../config) you wish to override minus the `.yml` extension and with a prefix of `JBP_CONFIG`. The value of the variable should be valid inline YAML. See the [Liberty container](container-liberty.md#common-configuration-overrides), [OpenJDK JRE](open-jdk.md#common-configuration-overrides), and [Spring Auto Reconfiguration framework](framework-spring-auto-reconfiguration.md#common-configuration-overrides) for examples. Also, see the sample [manifest.yml](./configuration/manifest.yml) file that uses configuration overrides environment variables to set Liberty features and configure version of the IBM JRE.

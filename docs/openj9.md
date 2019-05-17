[//]:# IBM WebSphere Application Server Liberty Buildpack
[//]:# Copyright 2019 the original author or authors.
[//]: #
[//]: # Licensed under the Apache License, Version 2.0 (the "License");
[//]: # you may not use this file except in compliance with the License.
[//]: # You may obtain a copy of the License at
[//]: #
[//]: #      http://www.apache.org/licenses/LICENSE-2.0
[//]: #
[//]: # Unless required by applicable law or agreed to in writing, software
[//]: # distributed under the License is distributed on an "AS IS" BASIS,
[//]: # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
[//]: # See the License for the specific language governing permissions and
[//]: # limitations under the License.

# OpenJ9
The [OpenJ9][] is an alternative Java virtual machine from the [Eclipse Foundation](https://eclipse.org). The OpenJ9 JVM must be explicitly enabled to be used by the Liberty buildpack. To enable OpenJ9 set the `JVM` environment variable to the `openj9` value. For example, add the following to your *manifest.yml* file:

```bash
---
env:
  JVM: openj9
```

Unless otherwise configured, the version of OpenJ9 that will be used is specified in the [`config/openj9.yml`][] file. Versions of Java from the `8` and `11` lines are currently available.

The Liberty buildpack uses the [IBM SDK](ibm-jdk.md) by default.

## Configuration

OpenJ9 can be configured by modifying the [`config/openj9.yml`][] file in the buildpack fork or by passing [an environment variable](configuration.md) that overrides configuration in the yml file.

| Name | Description
| ---- | -----------
| `version` | The version of OpenJ9 to use. Candidate versions can be found on the [AdpotOpenJDK page](https://adoptopenjdk.net/index.html?jvmVariant=openj9). |
| `type`  | `jre` (default) or `jdk`. |
| `heap_size` | `normal` (default) or `large`.   |
| `heap_size_ratio` | The ratio that is used to calculate the maximum heap size. The default heap size ratio is `0.75` (75% of the total available memory).

## Common Configuration Overrides

The OpenJ9 [configuration can be overridden](configuration.md) with the `JBP_CONFIG_OPENJ9` environment variable. The value of the variable should be valid inline YAML. For example:

1. Use OpenJ9 version 8:

   ```bash
   $ cf set-env myApplication JBP_CONFIG_OPENJ9 'version: 8.+'
   ```

1. Use full JDK instead of JRE:

   ```bash
   $ cf set-env myApplication JBP_CONFIG_OPENJ9 'type: jdk'
   ```

[`config/openj9.yml`]: ../config/openj9.yml
[OpenJ9]: https://www.eclipse.org/openj9/
[repositories]: util-repositories.md

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

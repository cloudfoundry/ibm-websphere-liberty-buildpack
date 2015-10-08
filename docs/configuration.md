Configuration
=============

The buildpack configuration can be overridden with an environment variable matching the [configuration file](../config) you wish to override minus the `.yml` extension and with a prefix of `JBP_CONFIG`. The value of the variable should be valid inline YAML. See the [Liberty container](container-liberty.md#common-configuration-overrides), [OpenJDK JRE](open-jdk.md#common-configuration-overrides), and [Spring Auto Reconfiguration framework](framework-spring-auto-reconfiguration.md#common-configuration-overrides) for examples. Also, see the sample [manifest.yml](./configuration/manifest.yml) file that uses configuration overrides environment variables to set Liberty features and configure version of the IBM JRE.


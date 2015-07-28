Configuration
=============

Buildpack configuration can be overridden with an environment variable matching the [configuration file](../config) you wish to override minus the `.yml` extension and with a prefix of `JBP_CONFIG`. The value of the variable should be valid inline yaml. For example:

1. Configure the buildpack to use [Liberty profile](container-liberty.md) beta:

    ```bash
    cf set-env myApplication JBP_CONFIG_LIBERTY 'version: 2015.+'
    ```

1. Configure the buildpack with a custom set of [Liberty profile](container-liberty.md) features (for WAR and EAR files only):

    ```bash
    cf set-env myApplication JBP_CONFIG_LIBERTY 'app_archive: {features: [jsp-2.2, websocket-1.1]}'
    ```

1. Configure the buildpack to use [OpenJDK](open-jdk.md) 8:

   ```bash
   cf set-env myApplication JBP_CONFIG_OPENJDK 'version: 1.8.+'
   cf set-env myApplication JVM openjdk
   ```

1. Configure the buildpack to use [OpenJDK](open-jdk.md) 8 with larger Metaspace size:

   ```bash
   cf set-env myApplication JBP_CONFIG_OPENJDK '[version: 1.8.+, memory_sizes: { metaspace: 256m }]'
   cf set-env myApplication JVM openjdk
   ```

1. Disable [Spring Auto Reconfiguration](framework-spring-auto-reconfiguration.md):

   ```bash
   cf set-env myApplication JBP_CONFIG_SPRINGAUTORECONFIGURATION 'enabled: false'
   ```

The environment variables can also be specified in the applications `manifest.yml` file. See the [Environment Variables][] documentation for more information.

[Environment Variables]: http://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html#env-block


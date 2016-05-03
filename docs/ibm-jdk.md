# IBM JRE
The IBM JRE is the default JRE used by the Liberty buildpack. Unless otherwise configured, the version of IBM JRE that will be used is specified in the [`config/ibmjdk.yml`][] file. If necessary, the IBM JRE can also be explicitly enabled by setting the `JVM` environment variable to `ibmjdk`. For example, using the `manifest.yml` file:

```bash
---
env:
  JVM: ibmjdk
```

The Liberty buildpack also supports [OpenJDK](open-jdk.md) as an alternative Java runtime.

## Configuration

The JRE can be configured by modifying the [`config/ibmjdk.yml`][] file in the buildpack fork or by passing [an environment variable](configuration.md) that overrides configuration in the yml file. 

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the IBM JRE repository index ([details][repositories]).
| `version` | The version of Java runtime to use.  Candidate versions can be found [here][index.yml].
| `heap_size_ratio` | The ratio that is used to calculate the maximum heap size. The default heap size ratio is `0.75` (75% of the total available memory).

## Common Configuration Overrides

The IBM JRE [configuration can be overridden](configuration.md) with the `JBP_CONFIG_IBMJDK` environment variable. The value of the variable should be valid inline YAML. For example:

1. Adjust heap size ratio:

   ```bash
   $ cf set-env myApplication JBP_CONFIG_IBMJDK 'heap_size_ratio: 0.90'
   ```

1. Use IBM JRE version 7:

   ```bash
   $ cf set-env myApplication JBP_CONFIG_IBMJDK 'version: 1.7.+'
   ```

[`config/ibmjdk.yml`]: ../config/ibmjdk.yml
[index.yml]: http://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/meta/jre/linux/x86_64/index.yml
[repositories]: util-repositories.md


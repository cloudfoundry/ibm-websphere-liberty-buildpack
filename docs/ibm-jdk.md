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

[`config/ibmjdk.yml`]: ../config/ibmjdk.yml
[index.yml]: http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/jre/index.yml
[repositories]: util-repositories.md


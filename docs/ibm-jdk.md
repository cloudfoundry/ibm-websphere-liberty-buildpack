# IBM JDK
The IBM JDK is the default used with Liberty profile. You do not need to change the `manifest.yml` file or configure anything else to use the IBM JDK. The behavior is the same as setting the `JVM` environment variable to `ibmjdk`. For example, using the `manifest.yml` file:

```bash
---
env:
  JVM: ibmjdk
```

If you would prefer to use the Open JDK then please read [Open JDK](open-jdk.md).

## Configuration

The JRE can be configured by modifying the [`config/ibmjdk.yml`][] file in the buildpack fork or by passing [an environment variable](configuration.md) that overrides configuration in the yml file. 

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the IBM JRE repository index ([details][repositories]).
| `version` | The version of Java runtime to use.  Candidate versions can be found [here][index.yml].

[`config/ibmjdk.yml`]: ../config/ibmjdk.yml
[index.yml]: http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/jre/index.yml
[repositories]: util-repositories.md


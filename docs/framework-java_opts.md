# `JAVA_OPTS` Framework
The `JAVA_OPTS` Framework contributes arbitrary Java options to the application at runtime.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td><tt>java_opts</tt> set in the <tt>config/java_opts.yml</tt> file or the <tt>JAVA_OPTS</tt> environment variable.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>java-opts</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.


## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

To configure the framework, you can modify the [`config/javaopts.yml`][] file.

| Name | Description
| ---- | -----------
| `from_environment` | Whether to append the value of the JAVA_OPTS environment variable to the collection of Java options
| `java_opts` | The Java options that can be used when running the application.  All values are used without modification when invoking the JVM. The options are specified as a single YAML scalar in plain style or enclosed in single or double quotes.

## Example
```bash
# JAVA_OPTS configuration
---
from_environment: false
java_opts: -Xloggc:$PWD/beacon_gc.log -verbose:gc
```

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/javaopts.yml`]: ../config/javaopts.yml

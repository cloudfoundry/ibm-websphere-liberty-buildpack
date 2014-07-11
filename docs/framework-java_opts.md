# `JAVA_OPTS` Framework
The `JAVA_OPTS` Framework provides [Java options][] to the application at runtime.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>The <tt>java_opts</tt> Framework is set in the <tt>config/java_opts.yml</tt> file or in the <tt>JAVA_OPTS</tt> environment variable.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>java_opts</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.


## Configuration
For more information about configuring the buildpack, see [Configuration and Extension][].

To configure the framework, you can modify the [`config/javaopts.yml`][] file.

| Name | Description
| ---- | -----------
| `from_environment` | Whether to append the value of the JAVA_OPTS environment variable to the collection of Java options, to disable this functionality, remove the <tt>from_environment</tt> key.
| `java_opts` | The Java options that can be used when running the application.  All values are used without modification when invoking the JVM. The options are specified as a single YAML scalar in plain style or enclosed in single or double quote marks.

## Example
```bash
# JAVA_OPTS configuration
---
from_environment: false
java_opts: -Xloggc:$PWD/beacon_gc.log -verbose:gc
```

[Java options]: http://www-01.ibm.com/support/knowledgecenter/SSYKE2_6.0.0/com.ibm.java.doc.diagnostics.60/diag/appendixes/cmdline/commands_jvm.html?lang=en
[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/javaopts.yml`]: ../config/javaopts.yml

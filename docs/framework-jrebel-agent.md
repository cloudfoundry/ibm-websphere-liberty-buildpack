# JRebel Agent Framework
This framework enables the use of [JRebel][jrebel] with deployed applications. Pushing any [JRebel Cloud/Remote][remoting] enabled application (containing `rebel-remote.xml`) to the Bluemix cloud platform will automatically download the latest version of JRebel and set it up for use.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Presence of a <tt>rebel-remote.xml</tt> file inside the application archive. This file is present in every application that is configured to use <a href="http://manuals.zeroturnaround.com/jrebel/remoting/index.html" target="_blank">JRebel Cloud/Remote</a>.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>jrebel-&lt;version&gt;</tt></td>
  </tr>
</table>

Tags are printed to standard output by the Buildpack detect script.

For more information regarding setup and configuration, please refer to the [JRebel with IBM Bluemix tutorial][bluemix].

## Configuration
The framework can be configured by modifying the [`config/jrebelagent.yml`][jrebelagentyml] file in a buildpack fork.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the JRebel repository index.
| `version` | The version of JRebel to use.

[jrebel]: http://zeroturnaround.com/software/jrebel/
[remoting]: http://manuals.zeroturnaround.com/jrebel/remoting/index.html
[bluemix]: http://manuals.zeroturnaround.com/jrebel/remoting/bluemix.html
[jrebelagentyml]: ../config/jrebelagent.yml
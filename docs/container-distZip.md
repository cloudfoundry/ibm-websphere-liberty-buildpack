# Dist Zip Container
The Dist Zip Container allows applications packaged in [`distZip`-style][] to be run.

<table border>
  <tr>
    <td><strong>Detection Criterion</strong></td><td><ul>
      <li>A start script in the <tt>bin/</tt> subdirectory of the application directory or one of its immediate subdirectories (but not in both), and</li>
      <li>A JAR file in the <tt>lib/</tt> subdirectory of the application directory or one of its immediate subdirectories (but not in both)</li>
    </ul></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>dist-zip</tt></td>
  </tr>
</table>
Tags are printed to standard output by the Buildpack `detect` script.

If the application uses Spring, [Spring profiles][] can be specified by setting the [`SPRING_PROFILES_ACTIVE`][] environment variable. This is automatically detected and used by Spring. The [Spring Auto-reconfiguration Framework](framework-spring-auto-reconfiguration.md) will specify the `cloud` profile in addition to any others.

## Configuration

The Dist Zip Container cannot be configured.

[`distZip`-style]: http://www.gradle.org/docs/current/userguide/application_plugin.html
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[`SPRING_PROFILES_ACTIVE`]: http://docs.spring.io/spring/docs/4.0.0.RELEASE/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME

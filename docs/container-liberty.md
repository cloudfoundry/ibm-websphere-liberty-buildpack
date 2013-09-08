# Liberty Container
The Liberty Container allows a web application or liberty server to be run.  These applications are run as the a web application in a Liberty container.

<table border>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a <tt>server.xml</tt> or <tt>WEB-INF/</tt> folder in the application directory</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>liberty-&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

In order to specify [Spring profiles][], set the [`SPRING_PROFILES_ACTIVE`][SPRING_PROFILES_ACTIVE] environment variable.  This is automatically detected and used by Spring.

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][Configuration_and_Extension].

The container can be configured by modifying the [`config/liberty.yml`][liberty.yml] file.  The container uses the [`Repository` utility support][repositories] and so it supports the [version syntax][version_syntax] defined there.


| Name | Description
| ---- | -----------
|`repository_root`| The URL of the Liberty repository index ([details][repositories])  
|`version`| The version of Liberty to use. Candidate versions can be found in [this listing][liberty.yml].  

[Configuration_and_Extension]: ../README.md#Configuration-and-Extension
[liberty.yml]: ../config/liberty.yml
[repositories]: util-repositories.md
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[SPRING_PROFILES_ACTIVE]: http://static.springsource.org/spring/docs/3.1.x/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
[version_syntax]: util-repositories.md#version-syntax-and-ordering
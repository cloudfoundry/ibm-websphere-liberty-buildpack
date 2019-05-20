# Spring Auto Reconfiguration Framework
The Spring Auto Reconfiguration Framework causes an application to be automatically reconfigured to work with configured cloud services.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a <tt>spring-core*.jar</tt> file in the application directory</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>spring-auto-reconfiguration-&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the Buildpack detect script.

If the `/WEB-INF/web.xml` file exists, the framework will modify it in addition to making the auto reconfiguration JAR available on the classpath.  These modifications include:

1. Augmenting `contextConfigLocation`
    1. The function starts by enumerating the current `contextConfigLocation`s. If none exist, a default configuration is created with `/WEB-INF/application-context.xml` or `/WEB-INF/<servlet-name>-servlet.xml` as the default.
    2. An additional location is then added to the collection of locations:
        * If the `ApplicationContext` is XML-based `classpath:META- INF/cloud/cloudfoundry-auto-reconfiguration-context.xml`
        * If the `ApplicationContext` is annotation-based `org.cloudfoundry.reconfiguration.spring.web.CloudAppAnnotationConfigAutoReconfig`
2. Augmenting `contextInitializerClasses`
    1. The function starts by enumerating the current `contextInitializerClasses`.  If none exist, a default configuration is created with no value as the default.
    2. The `org.cloudfoundry.reconfiguration.spring.CloudApplicationContextInitializer` class is then added to the collection of classes.

## Configuration
For general information on configuring the Buildpack, refer to [Configuration and Extension][].

To configure the framework, you can modify the [`config/springautoreconfiguration.yml`][] file.  The framework uses the [`Repository` utility support][repositories] and it supports the [version syntax][].

| Name | Description
| ---- | -----------
| `enabled` | Whether to attempt auto-reconfiguration.
| `repository_root` | The URL of the Auto Reconfiguration repository index ([details][repositories]).
| `version` | The version of Auto Reconfiguration to use. You can find the candidate versions [here][].

## Common Configuration Overrides

The Spring Auto Reconfiguration framework [configuration can be overridden](configuration.md) with the `JBP_CONFIG_SPRINGAUTORECONFIGURATION` environment variable. The value of the variable should be valid inline YAML. For example:

1. Disable the framework:

   ```bash
   $ cf set-env myApplication JBP_CONFIG_SPRINGAUTORECONFIGURATION 'enabled: false'
   ```

The environment variables can also be specified in the [manifest.yml](http://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html) file.

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/springautoreconfiguration.yml`]: ../config/springautoreconfiguration.yml
[repositories]: util-repositories.md
[here]: http://download.pivotal.io.s3.amazonaws.com/auto-reconfiguration/lucid/x86_64/index.yml
[version syntax]: util-repositories.md#version-syntax-and-ordering

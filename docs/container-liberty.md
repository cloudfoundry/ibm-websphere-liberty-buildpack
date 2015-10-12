# Liberty Container
The Liberty container runs Java EE 6 and 7 applications on [IBM's WebSphere Application Server Liberty Profile](http://www14.software.ibm.com/webapp/wsbroker/redirect?version=phil&product=was-nd-mp&topic=thread_twlp_devenv). It recognizes Web Archive (WAR) and Enterprise Archive (EAR) files as well applications deployed as a [Liberty server directory](http://www14.software.ibm.com/webapp/wsbroker/redirect?version=phil&product=was-nd-dist&topic=twlp_setup_new_server) or [packaged server](http://www14.software.ibm.com/webapp/wsbroker/redirect?version=phil&product=was-nd-mp&topic=twlp_setup_package_server).

<table border>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td><ul>
	<li>Existence of a <tt>WEB-INF/</tt> folder in the application directory and <a href="java-main.md">Java Main</a> is not detected, or</li>
	<li>Existence of a <tt>META-INF/</tt> folder in the application directory and <a href="java-main.md">Java Main</a> is not detected, or</li>
	<li>Existence of a <tt>server.xml</tt> file in the application directory, or</li>
	<li>Existence of a <tt>wlp/usr/servers/*/server.xml</tt> file in the application directory.</li>
    </ul></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>liberty-&lang;version&rang;</tt>, <tt>WAR</tt> <i>(if WAR file is detected)</i>, <tt>EAR</tt> <i>(if EAR file is detected)</i>, <tt>SVR-DIR</tt> <i>(if Liberty server directory is detected)</i>, <tt>SVR-PKG</tt> <i>(if Liberty packaged server is detected)</i></td>
  </tr>
</table>
Tags are printed to standard output by the Buildpack `detect` script.

If the application uses Spring, [Spring profiles][] can be specified by setting the [`SPRING_PROFILES_ACTIVE`][] environment variable. This is automatically detected and used by Spring. The [Spring Auto-reconfiguration Framework](framework-spring-auto-reconfiguration.md) will specify the `cloud` profile in addition to any others.

## Configuration

The Liberty container can be configured by modifying the [`config/liberty.yml`][liberty.yml] file in the buildpack fork or by passing [an environment variable](configuration.md) that overrides configuration in the yml file. The container uses the [`Repository` utility support][repositories] and it supports the [version syntax][version_syntax].

| Name | Description
| ---- | -----------
|`repository_root`| The URL of the Liberty repository index ([details][repositories]).
|`version`| The version of the Liberty profile. You can find the candidate versions [here][index.yml].
| `type` | The archive type of Liberty runtime to download. One of `webProfile6`, `webProfile7`, `javaee7`, or `kernel`. The default value is `webProfile7`. 
|`minify`| Boolean indicating whether the Liberty server should be [minified](#minify). The default value is `false`.
| `liberty_repository_properties` | [Liberty repository configuration](#liberty-repository-configuration). 
| `app_archive` | [Default configuration](#default-configuration) for WAR and EAR files. 

#### Minify

Minification potentially reduces the size of the deployed Liberty server because only the requested features are included. This might result in longer push times.

The `minify` option can be overridden on a per-application basis by specifying a `minify` environment variable in the `manifest.yml` for the application. For example:

```
  env:
    minify: true
```

#### Liberty repository configuration

By default, the buildpack will download the Liberty features specified in the `server.xml` from the [Liberty repository][]. To disable this feature, set the `useRepository` option to `false`.

```yaml
liberty_repository_properties:
  useRepository: true
```

When the `useRepository` option to `true`, you can pass additional properties under the `liberty_repository_properties` element to customize the repository information. The additional properties that can be set are defined in the [`installUtility`](http://www14.software.ibm.com/webapp/wsbroker/redirect?version=phil&product=was-base-dist&topic=twlp_config_installutility) documentation. For example, the following specifies a custom feature repository and disables access to the [Liberty repository][]:

```yaml
liberty_repository_properties:
  useRepository: true
  useDefaultRepository: false
  myRepo.url: http://dev.repo.ibm.com:9080/ma/v1
  myRepo.user: myUser
  myRepo.userPassword: myPassword
```

#### Default configuration 

The buildpack provides a default `server.xml` configuration when deploying WAR or EAR files. That default configuration is populated with a list of Liberty features based on the `["app_archive"]["features"]` setting. The `["app_archive"]["implicit_cdi"]` setting controls whether archives that do not contain the `beans.xml` file are scanned for CDI annotations. 

```yaml
app_archive:
 # Scan archives that do not contain beans.xml for bean-definition annotations (cdi 1.2)
 implicit_cdi: false
 # Default features
 features: 
 - beanValidation-1.1
 - cdi-1.2
 - ejbLite-3.2
 - el-3.0
 - jaxrs-2.0
 - jdbc-4.1
 - jndi-1.0
 - jpa-2.1
 - jsf-2.2
 - jsonp-1.0
 - jsp-2.3
 - managedBeans-1.0
 - servlet-3.1
 - websocket-1.1
```

## Common Configuration Overrides

The Liberty container [configuration can be overridden](configuration.md) with the `JBP_CONFIG_LIBERTY` environment variable. The value of the variable should be valid inline YAML. For example:

1. Configure the Liberty container to enable a custom set of Liberty features (for WAR and EAR files only):

    ```bash
    $ cf set-env myApplication JBP_CONFIG_LIBERTY 'app_archive: {features: [jsp-2.3, websocket-1.1]}'
    ```

1. Configure the Liberty container to download and install Liberty profile runtime with all Java EE 7 features:

    ```bash
    $ cf set-env myApplication JBP_CONFIG_LIBERTY 'type: javaee7'
    ```

1. Configure the Liberty container to download and install Liberty profile beta:

    ```bash
    $ cf set-env myApplication JBP_CONFIG_LIBERTY 'version: 2015.+'
    ```

The environment variables can also be specified in the [manifest.yml](http://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html) file.

[liberty.yml]: ../config/liberty.yml
[repositories]: util-repositories.md
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[`SPRING_PROFILES_ACTIVE`]: http://docs.spring.io/spring/docs/4.0.0.RELEASE/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
[version_syntax]: util-repositories.md#version-syntax-and-ordering
[index.yml]: http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/index.yml
[Liberty repository]: https://developer.ibm.com/wasdev/downloads/


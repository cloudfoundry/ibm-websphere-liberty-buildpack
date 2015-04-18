# Liberty Container
You can run a web application or Liberty server package in the Liberty Container.

<table border>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a <tt>server.xml</tt> or <tt>WEB-INF/</tt> folder in the application directory</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>liberty-&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the Buildpack `detect` script.

To specify the [Spring profiles][], set the [`SPRING_PROFILES_ACTIVE`][SPRING_PROFILES_ACTIVE] environment variable.  This is automatically detected and used by Spring.

## Configuration

The Liberty container can be configured by modifying the [`config/liberty.yml`][liberty.yml] file in the buildpack fork or by passing [an environment variable](configuration.md) that overrides configuration in the yml file. The container uses the [`Repository` utility support][repositories] and it supports the [version syntax][version_syntax].

| Name | Description
| ---- | -----------
|`repository_root`| The URL of the Liberty repository index ([details][repositories]).
|`version`| The version of the Liberty profile. You can find the candidate versions [here][index.yml].
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

By default, the Buildpack will download the Liberty features specified in the `server.xml` from [Liberty repository](https://developer.ibm.com/wasdev/downloads/). To disable this feature, set the `useRepository` option to `false`.

```yaml
liberty_repository_properties:
  useRepository: true
```

#### Default configuration 

The buildpack provides a default `server.xml` configuration when deploying WAR or EAR files. The configuration contains a list of Liberty features that are enabled by default. This set of features can be adjusted by modifying the `features` setting.

```yaml
app_archive:
 features: 
 - jsf-2.0
 - jsp-2.2
 - servlet-3.0
 - ejbLite-3.1
 - cdi-1.0
 - jpa-2.0
 - jdbc-4.0
 - jndi-1.0
 - managedBeans-1.0
 - jaxrs-1.1
```

[liberty.yml]: ../config/liberty.yml
[repositories]: util-repositories.md
[Spring profiles]:http://blog.springsource.com/2011/02/14/spring-3-1-m1-introducing-profile/
[SPRING_PROFILES_ACTIVE]: http://static.springsource.org/spring/docs/3.1.x/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
[version_syntax]: util-repositories.md#version-syntax-and-ordering
[index.yml]: http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/index.yml


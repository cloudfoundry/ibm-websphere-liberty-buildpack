# DynaTrace Agent Framework
The DynaTrace Agent Framework causes an application to be automatically configured to work with a bound [DynaTrace Service][] instance (Free trials available).

**NOTE**

* The DynaTrace agent slows down app execution significantly at first, but gets faster over time.  Setting the application manifest to contain `maximum_health_check_timeout` of 180 or more and/or using `cf push -t 180` or more when pushing a DynaTrace-monitored application may help.
* The DynaTrace agent can also be configured to exclude certain classes by specifying an exclude parameter in the service options in VCAP_SERVICES, which may help with performance issues.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound DynaTrace service.
      <ul>
        <li>Existence of a DynaTrace service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>dynatrace</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>dyna-trace-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
Users must provide their own DynaTrace service.  A user-provided DynaTrace service must have a name or tag with `dynatrace` in it so that the DynaTrace Agent Framework will automatically configure the application to work with the service.

The credentials payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `server` | The DynaTrace collector hostname to connect to.  Use `host:port` format for a specific port number.
| `profile` | (Optional) The DynaTrace server profile this is associated with.  Uses `Monitoring` by default.

**NOTE**

Be sure to open an Application Security Group to your DynaTrace collector prior to starting the application:
```
$ cat security.json
   [
     {
       "protocol": "tcp",
       "destination": "dynatrace_host",
       "ports": "9998"
     }
   ]

$ cf create-security-group dynatrace_group ./security.json
Creating security group dynatrace_group as admin
OK

$ cf bind-running-security-group dynatrace_group
Binding security group dynatrace_group to defaults for running as admin
OK

TIP: Changes will not apply to existing running applications until they are restarted.
```

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/dynatraceagent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the DynaTrace repository index ([details][repositories]).
| `version` | The version of DynaTrace to use.  This buildpack framework has been tested on 6.3.0.

### Additional Configuration
This buildpack supports adding additional DynaTrace Agent configuration options to the bound service through an options payload in the service.  The options payload should be a collection of name-value pairs similar to the following:
```
"options" : {
    "dynatrace-parameter": "value",
    "another-parameter": "value"
}
```

Supported parameters are any parameters which the [DynaTrace agent supports][]

[Configuration and Extension]: ./configuration.md
[`config/dynatraceagent.yml`]: ../config/dynatraceagent.yml
[DynaTrace agent supports]: https://community.dynatrace.com/community/display/DOCDT62/Agent+Configuration
[DynaTrace Service]: https://dynatrace.com
[repositories]: util-repositories.md
[version syntax]: util-repositories.md#version-syntax-and-ordering


# Dynatrace Appmon Agent Framework
The Dynatrace Appmon Agent Framework causes an application to be automatically configured to work with a bound [Dynatrace Service][] instance (Free trials available).

**NOTE**  

* The Dynatrace Appmon agent may slow down the start up time of large applications at first, but gets faster over time. Setting the application manifest to contain `maximum_health_check_timeout` of 180 or more and/or using `cf push -t 180` or more when pushing the application may help.
* Unsuccessful `cf push`s will cause dead entries to build up in the Dynatrace Appmon dashboard, as CF launches/disposes application containers. These can be hidden but will collect in the Dynatrace database.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound Dynatrace Appmon service.
      <ul>
        <li>Existence of a Dynatrace Appmon service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>dynatrace</code> as a substring and contains <code>server</code> field in the credentials. Note: The credentials must <b>NOT</b> contain <code>tenant</code> and <code>tenanttoken</code> in order to make sure the detection mechanism does not interfere with Dynatrace SaaS/Managed integration.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>dynatrace-appmon-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service
Users must provide their own Dynatrace Appmon service. A user-provided Dynatrace Appmon service must have a name or tag with `dynatrace` in it so that the Dynatrace Appmon Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `server` | The Dynatrace collector hostname to connect to. Use `host:port` format for a specific port number.
| `profile` | (Optional) The Dynatrace server profile this is associated with. Uses `Monitoring` by default.

**NOTE**

Be sure to open an Application Security Group to your Dynatrace collector prior to starting the application:
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

The framework can be configured by modifying the [`config/dynatrace_appmon_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Dynatrace Appmon repository index ([details][repositories]).
| `version` | The version of Dynatrace Appmon to use. This buildpack framework has been tested on 6.3.0 and 6.5.0.

### Additional Configuration
This buildpack supports adding additional Dynatrace Appmon Agent configuration options to the bound service through an options payload in the service. The options payload should be a collection of name-value pairs similar to the following:
```
"options" : {
    "dynatrace-parameter": "value",
    "another-parameter": "value"
}
```

Supported parameters are any parameters which the [Dynatrace Appmon Agent supports][]

[Configuration and Extension]: ./configuration.md
[`config/dynatraceappmonagent.yml`]: ../config/dynatraceappmonagent.yml
[Dynatrace Appmon Agent supports]: https://community.dynatrace.com/community/display/DOCDT62/Agent+Configuration
[Dynatrace Service]: https://www.dynatrace.com/
[repositories]: util-repositories.md
[version syntax]: util-repositories.md#version-syntax-and-ordering

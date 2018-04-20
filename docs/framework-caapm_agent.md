# CA APM Agent Framework
The CA APM Agent Framework causes an application to be automatically configured to work with a bound [CA APM Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single bound CA APM service. The existence of an CA APM service defined by the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service name, label or tag with <code>introscope</code> as a substring.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>introscope-agent=<version>&lt;version&gt;</tt></td>
  </tr>
</table>

Tags are printed to standard output by the buildpack detect script.

## User-Provided Service
When binding CA APM using a user-provided service, it must have name or tag with `introscope` in it. The credential payload can contain the following entries:

| Name | Description
| ---- | -----------
| agent_name | (Optional) The The name that should be given to this instance of the Introscope agent.
| agent_manager_credential | (Optional) The agent manager credential that is used to connect to the Enterprise Manager Server for SaaS.
| agent_manager_url | The url of the Enterprise Manager server.


## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].
The framework can be configured by modifying the [config] file in the buildpack fork. 

| Name | Description
| ---- | -----------
| repository_root | The URL of the CA APM repository index, which can be found in the [config] file.
| version | The version of CA APM Agent to use. 

[config]: ../config/caapmagent.yml
[CA APM Service]: https://www.ca.com/us/products/ca-application-performance-management.html
[Configuration and Extension]: ../README.md#configuration-and-extension

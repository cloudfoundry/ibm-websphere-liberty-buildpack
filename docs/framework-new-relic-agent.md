# New Relic Agent Framework
The New Relic Agent Framework causes an application to be automatically configured to work with a bound [New Relic Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single New Relic service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing at least one of the following:
      <ul>
        <li>name that has the substring <code>newrelic</code>. <strong>Note: </strong> This is only applicable to user-provided services</li>
        <li>label that has the substring <code>newrelic</code>.</li>
        <li>tags that have the substring <code>newrelic</code>.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>new-relic-&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the Buildpack detect script.

## User-Provided Service (Optional)
Users may optionally provide their own New Relic service. A user-provided New Relic service must have a name or tag with `newrelic` in it so that the New Relic Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `licenseKey` | The license key to use when authenticating

## Configuration
The framework can be configured by modifying the [`config/newrelicagent.yml`][] file in the buildpack fork.  

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the New Relic repository index.
| `version` | The version of New Relic to use. Candidate versions can be found in [this listing][].

### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/new_relic_agent` directory in the buildpack fork.  For example, to override the default `newrelic.yml` add your custom file to `resources/new_relic_agent/newrelic.yml`.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/newrelicagent.yml`]: ../config/newrelicagent.yml
[New Relic Service]: https://newrelic.com
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/new-relic/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering

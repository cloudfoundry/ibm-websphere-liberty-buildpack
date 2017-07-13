# Contrast Security Agent Framework
The Contrast Security Agent Framework causes an application to be automatically configured to work with a bound [Contrast Security Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single Contrast Security service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing at least one of the following:
      <ul>
        <li>name that has the substring <code>contrast-security</code>. <strong>Note: </strong> This is only applicable to user-provided services</li>
        <li>label that has the substring <code>contrast-security</code>.</li>
        <li>tags that have the substring <code>contrast-security</code>.</li>
        <li>credential payload containing the key <code>contrast_referral_tile<code></li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>contrast-security</tt></td>
  </tr>
</table>
Tags are printed to standard output by the Buildpack detect script.

## User-Provided Service (Optional)
Users may optionally provide their own Contrast Security service. A user-provided Contrast Security service must have a name or tag with `contrast-security` in it so that the Contrast Security Agent Framework will automatically configure the application to work with the service.

The credential payload of the service must contain the following entries:

| Name | Description
| ---- | -----------
| `username`    | A user with application onboarding permission
| `api_key`     | The user's api key
| `service_key` | The user's service key
| `teamserver_url` | The url to your Teamserver instance

## Configuration
The framework can be configured by modifying the [`config/contrastsecurityagent.yml`][] file in the buildpack fork.  

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Contrast Security repository index.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/contrastsecurityagent.yml`]: ../config/contrast_security_agent.yml
[Contrast Security Service]: https://www.contrastsecurity.com
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
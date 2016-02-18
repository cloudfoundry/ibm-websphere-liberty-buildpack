# `DynamicPULSE Agent` Framework
The DynamicPULSE Agent Framework enables the use of DynamicPULSE Agent with deployed applications.
Pushing any DynamicPULSE enabled application (containing `dynamicpulse-remote.xml`) will automatically download the DynamicPULSE Agent and set it up for use.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Presence of a <tt>/WEB-INF/dynamicpulse-remote.xml</tt> file inside the application archive. The detail of this file is shown in DynamicPULSE Getting Started Guide.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>DynamicPULSE-&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.


## User Provided Service
Users must provide DynamicPULSE Center service on the SoftLayer through purchasing DynamicPULSE on IBM Cloud marketplace.


## Configuration
This framework does not have any configuration files.
For more information about configuring the buildpack, see [Configuration and Extension][].



[Configuration and Extension]: ../README.md#Configuration-and-Extension

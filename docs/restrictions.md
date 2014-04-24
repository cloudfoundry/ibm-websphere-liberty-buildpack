# Restrictions

1. EBA applications are currently only partially supported.
If you would like you use these then you will need to push a
server containing the EBA application.

2. The use of server.xml files that contain include statements
 is not yet supported.

3. When using a Liberty Profile server in a Cloud Foundry environment
the supported features includes those listed under the categories: **Java
EE Web Profile**, **Enterprise OSGi**, and **Operations** categories as
described here, [Liberty features][]. Features listed under the categories:
**Systems Management** and **z/OS** are not supported when running in a Cloud
Foundry environment.

4. Support for two-phase commit global transactions is disabled for
applications running on a Liberty Profile server running in a Cloud
Foundry environment.

5. HTTPS connections do not terminate at the Liberty Profile server when
it runs in a Cloud Foundry environment. This means that you cannot use the
`<ssl-1.0>` feature in order to configure the server. You should have a look at
the documentation for your PaaS provider in order to understand how SSL support
is provided in their environment.

6. Due to the limitations mentioned previously around support for SSL we are
currently unable to provide support for external JMX connections. This impacts
the use of features such as: `<restConnector-1.0>`.

[Liberty features]: http://pic.dhe.ibm.com/infocenter/wasinfo/v8r5/index.jsp?topic=%2Fcom.ibm.websphere.wlp.nd.doc%2Fae%2Frwlp_feat.html
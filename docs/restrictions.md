# Restrictions

1. EBA applications are currently not supported. If you attempt
to push an EBA application on it's own then the push will fail.
You can, however, push a server package that contains a pre-
installed EBA application.

2. The use of server.xml files that contain include statements
is not yet supported. The include statements are currently
ignored by the buildpack. This impacts the processing
performed during staging, such as service plug-in processing.
The Liberty profile server itself is unaffected and will
continue to support include statements in server.xml files.

3. When using a Liberty Profile server in a Cloud Foundry environment
the supported features includes those listed under the categories: **Java
EE Web Profile**, **Enterprise OSGi**, and **Operations** categories as
described here, [Liberty features][]. Features listed under the categories:
**Systems Management** and **z/OS** are not supported when running in a Cloud
Foundry environment.

4. Support for two-phase commit global transactions is disabled for
applications running on a Liberty Profile server running in a Cloud
Foundry environment. The is due to the lack of a mechanism for Liberty
to perform transaction recovery when running in a Cloud Foundry environment.

5. Inbound HTTPS connections do not terminate at the Liberty Profile server when
it runs in a Cloud Foundry environment. This means that if you try to configure
an HTTPS endpoint on the server using the `<ssl-1.0>` feature then that endpoint
will not be accessible to users of your application. You should have a look at the
documentation for your PaaS provider in order to understand how SSL support
is provided in their environment.

6. Due to the limitations mentioned previously around inbound HTTPS endpoints
we are currently unable to provide support for external JMX connections.
This means that features such as `<restConnector-1.0>` will not work in a
Cloud Foundry environment.

[Liberty features]: http://pic.dhe.ibm.com/infocenter/wasinfo/v8r5/index.jsp?topic=%2Fcom.ibm.websphere.wlp.nd.doc%2Fae%2Frwlp_feat.html
# Restrictions

1. EBA applications are not supported. If you attempt
to push an EBA application on its own, the push fails.
However, you can push a server package containing a
preinstalled EBA application.

2. Using server.xml files that contain include statements
is now supported by the buildpack. However, remote configuration
files, accessible via HTTP, are not supported. The Liberty
profile server itself is unaffected and continues to support
include statements in server.xml files.

3. If you use a Liberty Profile server in a Cloud Foundry environment
the supported features include those listed under the categories: **Java
EE Web Profile**, **Enterprise OSGi**, **Operations**, and **Extended
Programming Models** described here, [Liberty features][]. Features
listed under the categories: **Systems Management** and **z/OS** are not
supported when running in a Cloud Foundry environment.

4. Support for two-phase commit global transactions is disabled for
applications running on a Liberty Profile server running in a Cloud
Foundry environment. There is not a mechanism for the Liberty Profile 
to perform transaction recovery when running in a Cloud Foundry environment.

5. Inbound HTTPS connections do not terminate at the Liberty Profile server when
it runs in a Cloud Foundry environment. If you configure
an HTTPS endpoint on the server using the `<ssl-1.0>` feature, that endpoint
is not accessible to users of your application. Read the documentation 
for your PaaS provider in order to understand how SSL support
is provided in their environment.

6. Due to the restrictions mentioned previously with inbound HTTPS endpoints, 
there is no support for external JMX connections.
This means that features such as `<restConnector-1.0>` do not work in a
Cloud Foundry environment.

7. As the use of Liberty collectives is not supported in a Cloud Foundry
environment, the use of the `<collectiveMember-1.0>` feature is not supported
in that environment either.


[Liberty features]: http://pic.dhe.ibm.com/infocenter/wasinfo/v8r5/index.jsp?topic=%2Fcom.ibm.websphere.wlp.nd.doc%2Fae%2Frwlp_feat.html

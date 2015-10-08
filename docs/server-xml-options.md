Buildpack-enabled Options for server.xml
========================================

Liberty's server behavior is controlled through a file with the name `server.xml`.

## WAR and EAR Files
If you are pushing a WAR, EAR or "exploded" (i.e. unzipped) file of either type, then a
server.xml will be generated for you with the correct parameters for use
with Cloud Foundry.  That server.xml will look something like this:

```xml
<server>
    <featureManager>
        <feature>beanValidation-1.1</feature>
        <feature>cdi-1.2</feature>
        <feature>ejbLite-3.2</feature>
        <feature>el-3.0</feature>
        <feature>jaxrs-2.0</feature>
        <feature>jdbc-4.1</feature>
        <feature>jndi-1.0</feature>
        <feature>jpa-2.1</feature>
        <feature>jsf-2.2</feature>
        <feature>jsonp-1.0</feature>
        <feature>jsp-2.3</feature>
        <feature>managedBeans-1.0</feature>
        <feature>servlet-3.1</feature>
        <feature>websocket-1.1</feature>
    </featureManager>
    <application name='myapp' location='myapp.war' type='war' context-root='/'/>
    <cdi12 enableImplicitBeanArchives='false'/>
    <httpEndpoint id='defaultHttpEndpoint' host='*' httpPort='${port}'/>
    <webContainer trustHostHeaderPort='true' extractHostHeaderPort='true'/>
    <include location='runtime-vars.xml'/>
    <logging logDirectory='${application.log.dir}' consoleLogLevel='INFO'/>
    <httpDispatcher enableWelcomePage='false'/>
    <applicationMonitor dropinsEnabled='false' updateTrigger='mbean'/>
    <config updateTrigger='mbean'/>
</server>

```

**NOTE**: The `application` element will be updated with the type of the application you deployed (war or ear) and the context root for your application. By default, the context root of `/` is used, unless otherwise set in the `WEB-INF/ibm-web-ext.xml` file embedded with your application. 

If you deployed an application using the command `cf push foo`, and your domain is `mydomain.com`, and the application uses the default context root, the application will be accessible from `http://foo.mydomain.com/`. If the application uses a non-default context root, say `/bar`, the application will be accessible from `http://foo.mydomain.com/bar`.

Since you are not pushing a server.xml with your application, you are foregoing most of control over the server's behavior, and the default behavior is assumed. However, you can adjust some things such as the feature list. See the [Liberty container](container-liberty.md#common-configuration-overrides) for details.

## Server Configurations (including a server.xml)

### Liberty Directory Push
Another way of deploying your application is to use the
`./bin/server package myServer --include=usr` command from your Liberty
installation in order to package the `usr` directory of your server.
If you run the `cf push -p myServer.zip` command from the directory
containing your packaged server (e.g. `/usr/servers/myServer`) then that
will push the packaged server to the cloud. The buildpack will detect
the server.xml contained within the package and proceed to modify it.

You can also use this method to install your own Liberty features.
By placing your feature manifest in the `${wlp.user.dir}/extension/lib/features` 
directory and the feature bundle .jar in the `${wlp.user.dir}/extension/lib` directory,
your feature will be installed to that Liberty instance. When you package Liberty using 
`./bin/server package myServer --include=usr`, those features are also packaged, as they
are present in the `usr` directory. This means that when you push that packaged
server, these features will still be present in the `usr` directory and installed to that instance.
[More information on Packaging and installing Liberty features can be found here.](http://www-01.ibm.com/support/knowledgecenter/SSAW57_8.5.5/com.ibm.websphere.wlp.nd.iseries.doc/ae/twlp_feat_install.html?lang=en)


### Server Directory Push
If you execute `cf push` from the server directory of your application
(e.g. `/usr/servers/myServer`) then that will push the contents of that
directory to the cloud. The buildpack will detect the server.xml
in this directory and proceed to modify it.

## Invoking the Application

If your push is successful you will be able to invoke your application at the
following URL:

`http://subdomain.domain/contextRoot/urlPattern`

## Server.xml Modifications

When a packaged server or a Liberty server directory is pushed, the Liberty
buildpack detects the server.xml file along with your application. The Liberty
buildpack makes the following modifications to the server.xml file.

* The buildpack ensures that there is exactly one `httpEndpoint` element in the file.
* The buildpack ensures that the `httpPort` attribute in the `httpEndpoint` element
points to a system variable that is called `${port}`.
* The buildpack ensures that a `runtime-vars.xml` file is logically merged
with your server.xml file.  Specifically, the buildpack appends the line
`<include location="runtime-vars.xml" />` to your server.xml file.

## Referenceable Variables

The following variables are defined in the runtime-vars.xml file, and referenced
from a pushed server.xml file. All the variables are case-sensitive.

* **${port}**: The http port that the Liberty server is listening on.
* **${vcap_console_port}**: The port where the vcap console is running
(usually the same as ${port}).
* **${vcap_app_port}**: The port where the app server is listening
(usually the same as ${port}).
* **${vcap_console_ip}**: The IP address of the vcap console
(usually the IP address that the Liberty server is listening on).
* **${application_name}**: The name of the application, as defined by
using the options in the cf push command.
* **${application_version}**: The version of this instance of the application,
which takes the form of a UUID, such as b687ea75-49f0-456e-b69d-e36e8a854caa.
This variable changes with each successive push of the application that contains
new code or changes to the application artifacts.
* **${host}**: The IP address of the DEA that is running the application
(usually the same as ${vcap_console_ip}).
* **${application_uris}**: A JSON-style array of the endpoints that can be
used to access this application, for example: myapp.mydomain.com.
* **${start}**: The time and date that the application was started, taking a
form similar to `2013-08-22 10:10:18 -0400`.

## Accessing the Information of Bound Services

The service variables that are accessible from a server.xml file follow [the specification that is defined by Cloud Foundry](http://docs.cloudfoundry.com/docs/using/services/spring-service-bindings.html#properties).
For more information about the Cloud Foundry specification, see Property placeholders in the Cloud Foundry documentation.

When you want to bind a Cloud Foundry service to your application, information
about the service, such as connection credentials, is included in the
environment variables that Cloud Foundry sends to the application.  These
variables are then accessible from the Liberty server configuration file. These
variables can be in one of the following forms:

* `cloud.services.<service-name>.<property>`, which describes the information such
as the name, type, and plan of the service.

* `cloud.services.<service-name>.connection.<property>`, which describes the connection
information for the service.

The typical set of information is as follows:

* **name**: The name of the service. For example, mysql-e3abd.
* **label**: The type of the created service. For example mysql-5.5.
* **plan**: The service plan, as inidicated by the unique identifier for that
plan. For example, 100.
* **connection.name**: A unique identifier for the connection, which takes the form
of a UUID. For example, d01af3a5fabeb4d45bb321fe114d652ee.
* **connection.hostname**: The hostname of the server that is running the
service. For example, mysql-server.mydomain.com.
* **connection.host**: The IP address of the server that is running the
service. For example, 9.37.193.2.
* **connection.port**: The port on which the service is listening for
incomming connections. For example, 3306, 3307.
* **connection.user**: The username that is used to authenticate this application
to the service.  The username is auto-generated by Cloud Foundry. For example,
unHwANpjAG5wT.
* **connection.username**: An alias for connection.user.
* **connection.password**: The password that is used to authenticate this application
to the service.  The password is auto-generated by Cloud Foundry. For example,
pvyCY0YzX9pu5.

For example, if you create a MySQL service: mysql-321, you can connect to this service
with the variable name `${cloud.services.mysql-321.connection.user}`.

## Example Server.xml for Using Services

The following is an example of a server.xml that was used to connect a
Liberty application ("ACE") with Postgresql and MySQL services named
`jtsql` and `jtsql2` respectively.

```
<!-- Enable features -->
    <featureManager>
		<feature>servlet-3.0</feature>
		<feature>sessionDatabase-1.0</feature>
		<feature>jsp-2.2</feature>
	</featureManager>

	<logging traceSpecification="com.ibm.ws.session.*=debug"
		consoleLogLevel="INFO" />

	<httpEndpoint id="defaultHttpEndpoint" host="*" httpPort="${port}" />

	<application name="ace" context-root="/" type="war" id="ace"
		location="ace.war" />

	<dataSource jndiName="jdbc/sessions" id="SessionDS">
		<jdbcDriver libraryRef="PostgreSQLLib" javax.sql.ConnectionPoolDataSource="org.postgresql.ds.PGConnectionPoolDataSource"/>
		<properties user="${cloud.services.jtsql.connection.user}"
			password="${cloud.services.jtsql.connection.password}" databaseName="${cloud.services.jtsql.connection.name}"
			serverName="${cloud.services.jtsql.connection.host}" portNumber="${cloud.services.jtsql.connection.port}" />
	</dataSource>

	<dataSource jndiName="jdbc/sessions2" id="SessionDS2">
		<jdbcDriver libraryRef="MySQLLib" />
		<properties user="${cloud.services.jtsql2.connection.user}"
			password="${cloud.services.jtsql2.connection.password}" databaseName="${cloud.services.jtsql2.connection.name}"
			serverName="${cloud.services.jtsql2.connection.host}" portNumber="${cloud.services.jtsql2.connection.port}" />
	</dataSource>

	<library id="PostgreSQLLib">
		<fileset dir="${server.config.dir}/lib" includes="postgresql-*.jar" />
	</library>

	<library id="MySQLLib" name="MySQL JDBC Drivers">
		<fileset dir="${server.config.dir}/lib" includes="mysql-connector-java-*.jar" />
	</library>

</server>
```

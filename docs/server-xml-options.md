Buildpack-enabled Options for Server.xml
========================================

Liberty's server behavior is controlled through a file with the name `server.xml`.

## WAR and EAR Files
If you are pushing a WAR, EAR or "exploded" (i.e. unzipped) file of either type, then a 
server.xml will be generated for you with the correct parameters for use 
with Cloud Foundry.  That server.xml will look something like this:

```
<server>
<server description="new server">

    <!-- Enable features -->
    <featureManager>
        <feature>webProfile-6.0</feature>
        <feature>jaxrs-1.1</feature>
    </featureManager>

    <httpEndpoint id="defaultHttpEndpoint"
                  host="*"
                  httpPort="${port}"
                   />    
</server>
```

**NOTE**: This server.xml will also contain a reference to the application
you pushed, with the type of the application (war/ear) and context root "/".  That is to say, if you pushed an app
using the command `cf push foo`, and your domain is `mydomain.com`, your
application will be accessible from `http://foo.mydomain.com/`.

Since you are not pushing a server.xml with your application, you are
foregoing any control over the server's behavior, and the default behavior
is assumed.

## Server Configurations (including a server.xml)

### Liberty Directory Push
The recommended way of deploying a Liberty server is to use the 
`./bin/server package myServer --include=usr` command from your Liberty 
installation and export your `usr` directory including your application. 
If you execute `cf push --path="myServer.zip"` from the server directory
of your application (e.g. `/usr/servers/myServer`) then the buildpack
will detect the server.xml in the server definitions contained within
the package and proceed to modify them.

### Server Directory Push
If you execute `cf push` from the server directory of your application
(e.g. `/usr/servers/myServer`) then the buildpack will detect the server.xml
in this directory and proceed to modify it.  

## Invoking the Application

If your push is successful you will be able to invoke your application at the
following URL:

`http://subdomain.domain/contextRoot/urlPattern`

## Server.xml Modifications

The following modifications happen to your server.xml:

* The buildpack ensures there is exactly one `httpEndpoint` element in your
configuration.
* The buildpack ensures that the `httpPort` attribute in this element
points to a system variable called `${port}`. This will replace any existing
settings for the `httpPort`.
* The buildpack ensures that the `runtime-vars.xml` file is logically merged
with your server.xml.  Specifically, the buildpack accomplishes this by
including the element:
`<include location="runtime-vars.xml" />` in your server.xml.

## Referencable Variables

The following variables end up in runtime-vars.xml, and are therefore
referencable from a pushed server.xml.  Note that these variables *are*
case-sensitive.

* **${port}**: The http port that the Liberty server is listening on.
* **${vcap_console_port}**: The port where the vcap console is running 
(usually the same as ${port}).
* **${vcap_app_port}**: The port where the app server is listening
(usually the same as ${port})..
* **${vcap_console_ip}**: The IP address of the vcap console 
(usually the IP address that the Liberty server is listening on).
* **${application_name}**: The name of the application, as defined using
the options in the cf push command.
* **${application_version}**: The version of this instance of the application.
Takes the form of a UUID, such as `b687ea75-49f0-456e-b69d-e36e8a854caa`, that
will change with each successive push of the app that contain new code or
changes to the application's artifacts.
* **${host}**: The IP address of the DEA that is running the application
(usually the same as ${vcap_console_ip}).
* **${application_uris}**: A JSON-style array of the endpoints that can be
used to access this application, for example: myapp.mydomain.com.
* **${start}**: The time and date that the application was started, taking a
form similar to `2013-08-22 10:10:18 -0400`.

## Accessing the Information of Bound Services

The service variables accessible from within serer.xml follow [the specifications defined by Cloud Foundry](http://docs.cloudfoundry.com/docs/using/services/spring-service-bindings.html#properties)

When you use bind a Cloud Foundry service to your application, information
about that service, including connection credentials, gets included in the
environment variables that Cloud Foundry sends to the application.  These
variables are then accessible from the Liberty server configuration. These
variables take the form:

`cloud.services.<service-name>.<property>`

**OR**

`cloud.services.<service-name>.connection.<property>`

Information describing the name, type, and plan of the service is accessible
through the first form.  Information describing the connection information for
the service take the second form.

The typical set of information is as follows:

* **name**: The name of the service (e.g. mysql-e3abd).
* **label**: The type of service created (e.g. mysql-5.5).
* **plan**: The service plan, as inidicated by the unique identifier for that
plan (e.g. 100).
* **connection.name**: A unique identifier for the connection, taking the form
of a UUID (e.g. d01af3a5fabeb4d45bb321fe114d652ee).
* **connection.hostname**: The hostname of the server that is running the 
service (e.g. mysql-server.mydomain.com).
* **connection.host**: The IP address of the server that is running the
service (e.g. 9.37.193.2).
* **connection.port**: The port on which the service is listening for
incomming connections (e.g. 3306, 3307).
* **connection.user**: The username used to authenticate this application
to this service.  The username is auto-generated by Cloud Foundry (e.g.
unHwANpjAG5wT).
* **connection.username**: An alias for **connection.user*.
* **connection.password**: The password used to authenticate this application
to this service.  The password is auto-generated by Cloud Foundry (e.g.
pvyCY0YzX9pu5).

So, for example, if I created a MySQL service named `mysql-321` then I could
access the username I should use to connect to this service with the variable
name `${cloud.services.mysql-321.connection.user}`.

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

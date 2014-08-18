Heroku 
========================================

[Heroku][] is a Platform-as-a Service (PaaS) provider. It is Heroku that first introduced the concept of buildpacks. Cloud Foundry later adopted this concept for its platform. As a result, many of the buildpacks that are developed for Heroku continue to work on Cloud Foundry and vice versa. 

You can use the Liberty Buildpack to deploy applications to Heroku. 

## Configuration

### Buildpack

To deploy a Liberty application to Heroku, you must configure the application to use the Liberty Buildpack:

* For a new application, use the `--buildpack` option to specify the Liberty Buildpack when you create the application:
  ```
  $ heroku create --buildpack https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack.git
  ```

* If you have an existing application, you can configure it to use the Liberty Buildpack via:
  ```
  $ heroku config:set BUILDPACK_URL=https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack.git
  ```

### License

You must also accept the Liberty and IBM JRE license in order to deploy an application using the Liberty Buildpack. See the [usage](https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack#usage) section for details on how to obtain the license codes for Liberty and IBM JRE. When you have the license codes, you can set them in the following way on Heroku:
```
$ heroku config:set IBM_JVM_LICENSE=<jvm license code> 
$ heroku config:set IBM_LIBERTY_LICENSE=<liberty license code>
```

## Deployment

### Git

You can use [Git](http://git-scm.com/) to deploy and manage applications to Heroku. See [Deploying with Git](https://devcenter.heroku.com/articles/git) for more information.

The Liberty Buildpack is designed to deploy compiled Java code. On Heroku, you must first check in the compiled applications code into a Git repository and then push the code to get it deployed with the Liberty Buildpack. 

### Deployment options

* To deploy a **server directory**, check in the contents into a Git repository and push. 

    For example:
    ```
    $ cd ~/wlp/usr/servers/defaultServer
    $ git init 
    $ git add .
    $ git commit -m "server directory"
    $ git push heroku master
    ```

* To deploy a **.war**, **.ear**, [**.jar**](java-main.md), or **packaged server** file, *expand* its contents first, and then check in the expanded contents into a Git repository and push.

    For example:
    ```
    $ mkdir ~/myapp
    $ cd ~/myapp
    $ jar xvf ~/myapp.war 
    $ git init 
    $ git add .
    $ git commit -m "war directory"
    $ git push heroku master
    ```

## Usage

### Service variables

Similarly, [as it is done for Cloud Foundry](https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack/blob/master/docs/server-xml-options.md#accessing-the-information-of-bound-services), the Liberty Buildpack on Heroku generates service variables for bound services. These variables are accessible from the Liberty server configuration file in the following form:

* `cloud.services.<service-name>.<property>` - where `<property>` maps to the properties listed below.

On Heroku, the buildpack looks for any environment variables that end with `_URL` or `_URI` suffix and converts them into service variables. Typically, the service variables are generated with the following information:

* **name**: The name of the service (see [below](#service-name)).
* **connection.url**: The service URL.
* **connection.uri**: An alias for **connection.url**.
* *(optional)* **connection.name**: The path part of the service URL. 
* *(optional)* **connection.hostname**: The hostname of the server that is running the service. 
* *(optional)* **connection.host**: An alias for **connection.hostname**.
* *(optional)* **connection.port**: The port on which the service is listening for incoming connections.
* *(optional)* **connection.user**: The username that is used to authenticate this application to the service.
* *(optional)* **connection.username**: An alias for **connection.user**.
* *(optional)* **connection.password**: The password that is used to authenticate this application to the service. 

The **connection.name**, **connection.hostname**, **connection.host**, **connection.port**, **connection.user**, **connection.username**, **connection.password** are optional and might not be set for some services. For example, the **connection.port** variable might not be set if the service URL does not specify one.

### Service name

Heroku does not provide a built-in way to associate a custom name with a service. However, the Liberty Buildpack uses the custom service names during [auto-configuration](#service-auto-configuration) to match a service to the right configuration elements in the server configuration or when generating service variables.

In general, the service name is the name of the environment variable exposed by the service without the `_URL` or `_URI` suffix. For example, the [MongoHQ][] service sets an environment variable named `MONGOHQ_URL`. The default service name would then be `mongohq` and the service variables would start with the `cloud.services.mongohq.` prefix. 

With the Liberty Buildpack you can associate a custom name with a service using the `SERVICE_NAME_MAP` environment variable. The `SERVICE_NAME_MAP` environment variable has the following syntax:
```
SERVICE_NAME_MAP=variableName=customName[,variableNameN=customNameN]*
```

Where `variableName` is the name of the environment variable exposed by the given service and `customName` is the user-defined name for the service.

For example:
```
$ heroku config:set SERVICE_NAME_MAP="MONGOHQ_URL=myMongo"
```

In this example, the service name for the [MongoHQ][] service is `myMongo` and the service variables start with the `cloud.services.myMongo.` prefix. 

### Service auto-configuration

The Liberty Buildpack performs auto-configuration for a subset of services. The buildpack automatically downloads appropriate client drivers and updates the `server.xml` configuration file with the right information for a given service. For example, for the [Heroku Postgres][] service, the Liberty Buildpack downloads the JDBC client driver and updates the `server.xml` file with the appropriate `dataSource` element. 

Currently, on Heroku, auto-configuration will be done for the [Heroku Postgres][], [ClearDB MySQL Database](https://addons.heroku.com/cleardb), [MongoLab](https://addons.heroku.com/mongolab), [MongoHQ][], and [MongoSoup](https://addons.heroku.com/mongosoup) add-ons. 

#### Opting out

You can opt-out from the service auto-configuration by setting the `services_autoconfig_excludes` environment variable. The environment variable has the following syntax:
```
services_autoconfig_excludes=variableName=excludeType[ variableName=excludeType]*
```
Where `variableName` is the name of the environment variable exposed by the given service and `excludeType` is set to:
* `all` - indicates opting out of auto-configuration for the service.
* `conifg` - indicates opting out of configuration updates only.

For example:
```
heroku config:set services_autoconfig_excludes="MONGOHQ_URL=all"
```

In this example, we opted out of auto-configuration for the [MongoHQ][] service.

## Limitations

The following is a list of features of the Liberty Buildpack that do not work on Heroku:

* Changing the JRE type by setting the `JVM` environment variable.

[Heroku]: https://heroku.com
[Heroku Postgres]: https://addons.heroku.com/heroku-postgresql
[MongoHQ]: https://addons.heroku.com/mongohq



# Service Plug-ins

Service plug-ins provide the means via which the Liberty buildpack can automatically configure the Liberty
profile server to work with the services that are bound to the deployed application. The plug-ins achieve
this by doing the following:

* Generate variable bindings for the bound services based on the content of VCAP_SERVICES.
* Install additional Liberty features and/or client libraries, e.g. JDBC drivers, required to access the bound services.
* Generate or update configuration elements in the server.xml required by the services.

If you want the application to manage the service directly, you can opt-out of automatic configuration for the
service by setting the services_autoconfig_excludes environment variable.

## Variable Bindings

When the application is bound to services, the service binding information is available in the VCAP_SERVICES environment
variable. The Liberty buildpack will parse the VCAP_SERVICES information and generate variable bindings that can be used
to configure the Liberty profile server. Further information on supported variable bindings can be found here, [Accessing
the Information of Bound Services].

## Install of Liberty features and client libraries

When you bind to a service, the service may require Liberty features to be configured in the featureManager stanza in the
server.xml file. The Liberty buildpack updates the featureManager stanza appropriately and installs the required supporting
binaries. If the service requires client driver jars, the jars will be downloaded to a well-known location in the Liberty
installation.

See the documentation for the bound service type for more details.

## User-Provided Service Instances

The Liberty buildpack will recognize user-provided services and install features and client libraries for you. The name
of the user-provided service must include the supported `service_filter` of the service that you want to have installed.
For example, a user-provided service named `myMongoInstance` would be recognized by the buildpack as a Mongo service.

The `service_filter` for a supported service can be found in the YAML files in the [service config dir].

## Generating or updating server.xml configuration

When you push an application, the Liberty buildpack generates configuration elements in the server.xml as described in
[Modifications]. When you bind a service, the Liberty buildpack may generate additional elements in the server.xml for
the bound service.

See the documentation for the bound service type for more details.

## Opting out of service auto configuration

To opt out of automatic service configuration, use the services_autoconfig_excludes environment variable. You can include
this environment variable in a manifest.yml or set it using the cf client.

You can opt out of automatic configuration of services on a per-service-type basis. You can choose to completely opt out,
or only opt out of server.xml configuration updates. The value you specify for the services_autoconfig_excludes environment
variable is a String as following:

*    The String can contain opt-out specifications for one or more service.
*    The opt out specification for a given service is service_type=option (no white spaces) where
    *    The service_type is the label for the service as displayed in VCAP_SERVICES.
    *    The option is either all or config.
*    If the String contains an opt-out specification for more than one service, the individual opt out specifications must
be separated by a single white space character.

More formally, the grammar of the String is:

```
Opt_out_string :: <service_type_specification[<delimiter>service_type_specification]*
<service_type_specification> :: <service_type>=<option>
<service_type> :: service type (service label as it appears in VCAP_SERVICES)
<option> :: all | config 
<delimiter> :: one white space character
```

Use the “all” option to opt out of all automatic configuration actions for a service. Use the “config” option to only opt out
of configuration update actions.

```
env:
  services_autoconfig_excludes: mongodb-2.2=all

env:
  services_autoconfig_excludes: mysql=config

env:
  services_autoconfig_excludes: mysql=config mongodb-2.2=all
``` 

[Accessing the Information of Bound Services]: server-xml-options.md#accessing-the-information-of-bound-services
[Modifications]: server-xml-options.md#serverxml-modifications
[service config dir]: /lib/liberty_buildpack/services/config

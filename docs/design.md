# Design
The Liberty Buildpack is designed as a collection of components.  These components are divided into three types: _JREs_, _Containers_, and _Frameworks_.

## JRE Components
JRE components represent the JRE that will be used when running an application.  This type of component is responsible for:

* Determining which JRE should be used

* Downloading and unpacking that JRE

* Resolving any JRE-specific options that should be used at runtime

Note: Only a single JRE component can be used to run an application.  If more than one JRE could be used, an error will be displayed and the application deployment will fail.

## Container Components
Container components represent the way that an application is run.  Container types range from traditional application servers and servlet containers to simple Java `main()` method execution.  This type of component is responsible for:

* Determining which container should be used

* Downloading and unpacking that container

* Producing the command that will be executed by Cloud Foundry at runtime

Note: Only a single container component can run an application.  If more than one container could be used, an error will be displayed and the application deployment will fail.

## Framework Components
Framework components represent additional behavior or transformations used when an application is run.  Framework types include the downloading of JDBC JARs for bound services and automatic reconfiguration of `DataSource`s in Spring configuration to match bound services.  This type of component is responsible for:

* Determining which frameworks are required

* Transforming the application

* Contributing any additional options that should be used at runtime

Note: Any number of framework components can be used when running an application.

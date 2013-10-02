Bootstrap.properties configuration options
==========================================

The bootstrap.properties file is normally used to configure the Liberty
server, but some options are not available when using the buildpack

## Ports

The default http port is configured for you by the buildpack, as documented
in [modifications][]. The default https port is currently not available.

## Logging

The console output is redirected to the stdout.log file and is available
via `cf logs`

[modifications]: server-xml-options.md#server.xml-modifications
Bootstrap.properties configuration options
==========================================

The `bootstrap.properties` file is used to configure the Liberty
server but, when running in Cloud Foundry, there are some special
considerations as documented below.

## Ports

The default HTTP port is configured for you by the Buildpack, as
documented in [modifications][]. The default HTTPS port is currently
not available.

## Logging

The console output is redirected to the `stdout.log` file and is
available via `cf logs`.

[modifications]: server-xml-options.md#serverxml-modifications
# Logging

The Buildpack logs to both
`<app dir>/.buildpack-diagnostics/buildpack.log` and standard error.
Logs are filtered according to the configured log level.

If the buildpack fails with an exception, the exception message is logged with a
log level of `ERROR` whereas the exception stack trace is logged with a log
level of `DEBUG` to prevent users from seeing stack traces by default.

## Sensitive Information in Logs

The Buildpack logs sensitive information, such as environment variables which may contain security
credentials.

Note: Be careful not to expose the sensitive information, for example
by posting standard error stream contents or the contents of `<app
dir>/.buildpack-diagnostics/buildpack.log` to a public discussion
list.

## Logger Usage
The `LoggerFactory` class in the `LibertyBuildpack::Diagnostics` module
manages a single instance of a subclass of the standard Ruby `Logger`.
The `Buildpack` class creates a logger which is shared
by all other classes and which is retrieved from the `LoggerFactory` as necessary:

    logger = LoggerFactory.get_logger

This logger is used in the same ways as the standard Ruby logger and supports
both parameter and block forms:

    logger.info('success')
    logger.debug { "#{costly_method}" }

## Configuration
For general information on configuring the Buildpack, refer to [Configuration and Extension][].

You can set the `$JBP_LOG_LEVEL` environment variable to configure the log level. There are five logs levels:

    DEBUG | INFO | WARN | ERROR | FATAL

For example:

    cf set-env <app name> JBP_LOG_LEVEL DEBUG

If `JBP_LOG_LEVEL` is not set, the default log level is read from the configuration in
`config/logging.yml`.

You can use any mixture of upper and lower case letters to specify the logging levels in the `JBP_LOG_LEVEL` environment variable and the `config/logging.yml` file.

If you do not set the `JBP_LOG_LEVEL` environment variable, the Ruby verbose and debug modes override the default log level and change it to `DEBUG`.


[Configuration and Extension]: ../README.md#Configuration-and-Extension
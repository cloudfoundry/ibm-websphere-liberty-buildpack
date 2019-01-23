# IBM WebSphere Application Server Liberty Buildpack [![Build Status](https://travis-ci.org/cloudfoundry/ibm-websphere-liberty-buildpack.svg?branch=master)](https://travis-ci.org/cloudfoundry/ibm-websphere-liberty-buildpack)

The `liberty-buildpack` is a [Cloud Foundry][] Buildpack for running applications on IBM's WebSphere Application Server [Liberty Profile][].

## Usage
To deploy applications using the IBM WebSphere Application Server Liberty Buildpack, you are required to accept the IBM Liberty license and IBM JRE license by following the instructions below:

1. Read the current IBM [Liberty-License][] and the current IBM [JVM-License][].
2. Extract the `D/N: <License code>` from the Liberty-License and JVM-License.
3. Add the following environment variables and extracted license codes to the `manifest.yml` file in the directory from which you push your application. For further information on the format of
the `manifest.yml` file refer to the [manifest documentation][].

    ```
      env:
        IBM_JVM_LICENSE: <jvm license code>
        IBM_LIBERTY_LICENSE: <liberty license code>
    ```

After you have set the license acceptance environment variables, use the following command to deploy the application with the IBM WebSphere Application Server Liberty Buildpack:

```bash
cf push <APP-NAME> -p <ARCHIVE> -b https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack.git
```

* For further details on the options available for deploying your applications see [options][].
* For further details on tuning the applications JVM see [tuning options][].
* For further details on pushing a Java Main application see [java main push][].

## Documentation
All Documentation is available in the Docs folder of the buildpack.

* [Liberty Buildpack Design Overview](docs/design.md)
* Containers
    * [Liberty Container](docs/container-liberty.md)
        * [Service Plug-ins](docs/service-plugins.md)
            * [MongoDB](docs/services/mongo.md)
            * [MySQL](docs/services/mysql.md)
            * [PostgreSQL](docs/services/postgresql.md)
    * [Java Main (for jars with a main() class)](docs/java-main.md)
    * [DistZip](docs/container-distZip.md)
* Frameworks
    * [AppDynamics Agent](docs/framework-app_dynamics_agent.md)
    * [CA APM Agent](docs/framework-caapm_agent.md)
    * [Contrast Security Agent](docs/framework-contrast-security-agent.md)
    * [Dynatrace Appmon Agent](docs/framework-dynatrace_appmon_agent.md)
    * [Dynatrace SaaS/Managed OneAgent](docs/framework-dynatrace_one_agent.md)
    * [DynamicPULSE Agent](docs/framework-dynamic_pulse_agent.md)
    * [Java Options](docs/framework-java_opts.md)
    * [JRebel Agent](docs/framework-jrebel-agent.md)
    * [New Relic Agent](docs/framework-new-relic-agent.md)
    * [Spring Auto Reconfiguration](docs/framework-spring-auto-reconfiguration.md)
* JVMs
    * [IBM SDK](docs/ibm-jdk.md)
    * [OpenJDK](docs/open-jdk.md)
    * [OpenJ9](docs/openj9.md)
* [Server Behavior xml Options](docs/server-xml-options.md)
* [Forking the buildpack](docs/forking.md)
* [Overriding buildpack configuration](docs/configuration.md)
* [Setting Environment Variables](docs/env.md)
* [Installation (admin buildpack into CF)](docs/installation.md)
* [Tuning](docs/tuning.md)
* [Logging](docs/logging.md)
* [Debugging the buildpack](https://github.com/cloudfoundry/java-buildpack/blob/master/docs/debugging-the-buildpack.md)
* [Troubleshooting](docs/troubleshooting.md)
* [Security](docs/security.md)
* [Restrictions](docs/restrictions.md)
* [Configuring Liberty with bootstrap.properties](docs/bootstrap-properties.md)
* [Applying an iFix to the Liberty runtime](docs/applying-ifix.md)
* Utilities
	* [Utility: Caches](docs/util-caches.md)
	* [Utility: Repositories](docs/util-repositories.md)
	* [Utility: Repository Builder](docs/util-repository-builder.md)
	* [Utility: Test Applications](docs/util-test-applications.md)

## Running Tests
To run the tests, do the following:

```bash
bundle install
bundle exec rake
```

If you want to use the RubyMine debugger, you may need to [install additional gems][].

```bash
bundle install --gemfile Gemfile.rubymine-debug
```

## Contributing
[Pull requests][] are welcome; see the [contributor guidelines][] for details.


[Apache License]: http://www.apache.org/licenses/LICENSE-2.0
[Cloud Foundry]: http://www.cloudfoundry.com
[Liberty Profile]: https://developer.ibm.com/wasdev/docs/introducing_the_liberty_profile/
[contributor guidelines]: CONTRIBUTING.md
[GitHub's forking functionality]: https://help.github.com/articles/fork-a-repo
[install additional gems]: http://stackoverflow.com/questions/11732715/how-do-i-install-ruby-debug-base19x-on-mountain-lion-for-intellij
[pull request]: https://help.github.com/articles/using-pull-requests
[Pull requests]: http://help.github.com/send-pull-requests
[options]: docs/server-xml-options.md
[tuning options]: docs/tuning.md
[java main push]: docs/java-main.md

[Liberty-License]: https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/18.0.0.4/lafiles/runtime/en.html
[JVM-License]: http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?la_formnum=&li_formnum=L-SMKR-AVSEUH&title=IBM%AE+SDK%2C+Java%99+Technology+Edition%2C+Version+8.0&l=en
[manifest documentation]: http://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html

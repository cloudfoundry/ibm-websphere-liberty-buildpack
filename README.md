[![Build Status](https://travis-ci.org/cloudfoundry/ibm-websphere-liberty-buildpack.png)](https://travis-ci.org/cloudfoundry/ibm-websphere-liberty-buildpack)

# IBM WebSphere Application Server Liberty Buildpack

The `liberty-buildpack` is a [Cloud Foundry][] Buildpack for running applications on IBM's WebSphere Application Server Liberty Profile. It is designed to run most "packaged" servers.

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

## Forking the buildpack   
To fork the Buildpack and host your own binaries, then complete the following:

1. Fork the [ibm-websphere-liberty-buildpack](https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack).

2. Clone the forked repository to your local machine.

3. Download the wlp-developers-runtime-8.5.5.2.jar from [wasdev.net][].

4. Download the latest IBM JRE for Linux from the [developerWorks Java site][].
  The download will be in an archive .bin format.
   
5. Copy the binaries to a location that the buildpack will be able to access via HTTP. For details see
  [Repositories][]. For an example see [Setting up your Web Server][example]

6. Modify the code in [`config/ibmjdk.yml`][ibmjdk.yml] to point to the JRE.

7. Modify the code in [`config/liberty.yml`][liberty.yml] to point to Liberty.

8. Commit and push the changes

9. You should now be able to deploy applications to your forked buildpack with the following command:

```bash
cf push <APP-NAME> -p <ARCHIVE> -b <URL to forked repository>
```
    
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
[contributor guidelines]: CONTRIBUTING.md
[GitHub's forking functionality]: https://help.github.com/articles/fork-a-repo
[install additional gems]: http://stackoverflow.com/questions/11732715/how-do-i-install-ruby-debug-base19x-on-mountain-lion-for-intellij
[pull request]: https://help.github.com/articles/using-pull-requests
[Pull requests]: http://help.github.com/send-pull-requests
[example]: docs/util-repositories.md#setting-up-your-web-server
[options]: docs/server-xml-options.md
[tuning options]: docs/tuning.md
[java main push]: docs/java-main.md
[Repositories]: docs/util-repositories.md
[ibmjdk.yml]: config/ibmjdk.yml
[liberty.yml]: config/liberty.yml
[wasdev.net]: http://wasdev.net
[developerWorks Java site]: https://www.ibm.com/developerworks/java/jdk/
[Liberty-License]: http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/8.5.5.2/lafiles/runtime//en.html
[JVM-License]: http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?la_formnum=&li_formnum=L-AWON-8GALN9&title=IBM%C2%AE+SDK%2C+Java-+Technology+Edition%2C+Version+7.0&l=en
[manifest documentation]: http://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html

# IBM WebSphere Application Server Liberty Buildpack

The `liberty-buildpack` is a [Cloud Foundry][] buildpack for running applications on IBM's WebSphere Application Server Liberty Profile.  It is designed to run most "packaged" servers.

## Usage
To deploy applications using the IBM WebSphere Application Server Liberty Buildpack, you are required to accept the IBM Liberty license and IBM JRE license by actioning the following:
* Read the current IBM [Liberty-License][] and the current IBM [JVM-License][].
* Extract the "D/N: {License code}" from the license.
* Add the following environment variables and extracted license codes inside of the "manifest.yml" file that gets pushed with your application. For further information on the format of
the manifest.yml file refer to the [manifest documentation][].

```
  env:
    IBM_JVM_LICENSE: {jvm license code}
    IBM_LIBERTY_LICENSE: {liberty license code}
```

* Once the license acceptance environment variables are set, use the following command:

```bash
cf push --buildpack https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack.git
```
For further details on the options available for deploying your applications see [options][]

## Forking the buildpack   
If you wish to fork the buildpack and host your own binaries, then complete the following:

* Fork the [ibm-websphere-liberty-buildpack](https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack).

* Clone the forked repository to your local machine.

* Download the wlp-developers-runtime-8.5.5.0.jar from [wasdev.net][].

* Download the latest IBM JRE for Linux from the [developerWorks Java site][].
  The download will be in an archive .bin format.
   
* Copy the binaries to a location that the buildpack will be able to access via HTTP. For details see
  [Repositories][]. For an example see [Setting up your Web Server][example]

* Modify the code in [`config/ibmjdk.yml`][ibmjdk.yml] to point to the JRE.

* Modify the code in [`config/liberty.yml`][liberty.yml] to point to Liberty.

* Commit and push the changes

* You should now be able to deploy applications to your forked buildpack with the following command:

```bash
cf push --buildpack "URL to forked repository"
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
[example]: docs/installation.md#setting-up-your-web-server
[options]: docs/server-xml-options.md
[Repositories]: docs/util-repositories.md
[ibmjdk.yml]: config/ibmjdk.yml
[liberty.yml]: config/liberty.yml
[wasdev.net]: http://wasdev.net
[developerWorks Java site]: https://www.ibm.com/developerworks/java/jdk/
[Liberty-License]: http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/8.5.5.0/lafiles/runtime//en.html
[JVM-License]: http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?la_formnum=&li_formnum=L-AWON-8GALN9&title=IBM%C2%AE+SDK%2C+Java-+Technology+Edition%2C+Version+7.0&l=en
[manifest documentation]: http://docs.cloudfoundry.com/docs/using/deploying-apps/manifest.html

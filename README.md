# IBM WebSphere Application Server Liberty Buildpack

The `liberty-buildpack` is a [Cloud Foundry][] buildpack for running applications on IBM's WebSphere Application Server Liberty Profile.  It is designed to run most "packaged" servers.

## Usage
In order to use the buildpack you will first need to complete the following:

* Fork the [ibm-websphere-liberty-buildpack](https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack).

* Clone the forked repository to your local machine.

* Download the wlp-developers-runtime-8.5.5.0.jar from [wasdev.net](http://wasdev.net).

* Download the latest IBM JRE for Linux from the [developerWorks Java site][].
  The download will be in a .bin format.
   
* Copy the binaries to a location that the buildpack will be able to access via HTTP. For details see
  [Repositories][]. For an example see [Setting up your Web Server][example]

* Modify the code in [`config/ibmjdk.yml`][ibmjdk.yml] to point to the JRE.

* Modify the code in [`config/liberty.yml`][liberty.yml] to point to Liberty.

* Commit and push the changes

* You should now be able to deploy your applications using the following command:

```bash
cf push --buildpack="URL to forked repository"
```
    
For further details on the options available for deploying your applications see [options][]
    

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
[developerWorks Java site]: https://www.ibm.com/developerworks/java/jdk/

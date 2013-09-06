# IBM WebSphere Application Server Liberty Buildpack

The `liberty-buildpack` is a [Cloud Foundry][] buildpack for running applications on IBM's WebSphere Application Server Liberty Profile.  It is designed to run most "packaged" servers.

## Usage
To use this buildpack refer to [Configuration and Extension][Configuration_and_Extension]

## Running Tests
To run the tests, do the following:

```bash
bundle install
bundle exec rake
```

If you want to use the RubyMine debugger, you may need to [install additional gems][].

## Contributing
[Pull requests][] are welcome; see the [contributor guidelines][] for details.

[Apache License]: http://www.apache.org/licenses/LICENSE-2.0
[Cloud Foundry]: http://www.cloudfoundry.com
[contributor guidelines]: CONTRIBUTING.md
[GitHub's forking functionality]: https://help.github.com/articles/fork-a-repo
[pull request]: https://help.github.com/articles/using-pull-requests
[Pull requests]: http://help.github.com/send-pull-requests
[Configuration_and_Extension]: docs/container-liberty.md#Configuration

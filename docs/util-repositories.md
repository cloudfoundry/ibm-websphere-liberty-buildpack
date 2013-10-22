# Repositories
Many components need to have access to multiple versions of binaries.  The buildpack provides a `Repository` abstraction to encapsulate version resolution and download URI creation.

## Repository Structure
The repository is an HTTP-accessible collection of files.  The repository root must contain an `index.yml` file that is a mapping of concrete versions to absolute URIs consisting of a series of lines of the form:
```yaml
<version>: 
    url: <URI of binary>
    license: <URI of license>
```

The collection of files may be stored alongside the index file or elsewhere.

An example filesystem might look like:

```
/index.yml
/ibm-java-jre-7.0-5.0-x86_64-archive.bin
/ibm-java-jre-7.0-5.0-x86_64-License.html
```

## Usage

The main class used when dealing with a repository is [`LibertyBuildpack::Repository::ConfiguredItem`][].  It provides a single method that is used to resolve a specific version to the URI containing the binary as well as a URI containing the License.

```ruby
# Finds an instance of the file based on the configuration.
#
# @param [Hash] configuration the configuration
# @option configuration [String] :repository_root the root directory of the repository
# @option configuration [String] :version the version of the file to resolve
# @param [Block, nil] version_validator an optional version validation block
# @return [LibertyBuildpack::Util::TokenizedVersion] the chosen version of the file
# @return [String] the URI and License URI of the chosen version of the file
def self.find_item(configuration, &version_validator)
```

Usage of the class might look like the following:

```ruby
version, uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration)
```

or with version validation:

```ruby
version, uri = LibertyBuildpack::Repository::ConfiguredItem.find_item(configuration) do |version|
  validate_version version
end
```

## Version Syntax and Ordering
Versions are composed of major, minor, micro, and optional qualifier parts (`<major>.<minor>.<micro>[_<qualifier>]`).  The major, minor, and micro parts must be numeric.  The qualifier part is composed of letters, digits, and hyphens.  The lexical ordering of the qualifier is:

1. hyphen
2. lowercase letters
3. uppercase letters
4. digits

## Version Wildcards
In addition to declaring a specific versions to use, you can also specify a bounded range of versions to use.  Appending the `+` symbol to a version prefix chooses the latest version that begins with the prefix.

| Example | Description
| ------- | -----------
| `1.+`   	| Selects the greatest available version less than `2.0.0`.
| `1.7.+` 	| Selects the greatest available version less than `1.8.0`.
| `1.7.0_+` | Selects the greatest available version less than `1.7.1`. Use this syntax to stay up to date with the latest security releases in a particular version.


[`LibertyBuildpack::Repository::ConfiguredItem`]: ../lib/liberty_buildpack/repository/configured_item.rb

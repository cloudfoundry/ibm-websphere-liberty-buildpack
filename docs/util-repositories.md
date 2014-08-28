# Repositories
The Liberty Buildpack provides a `Repository` abstraction to encapsulate version resolution and download URI creation. By the `Repository` abstraction, components can access multiple versions of binaries.  

## Repository Structure
The repository is an HTTP-accessible collection of files.  The repository root must contain an `index.yml` file that is a mapping of concrete versions to absolute URIs:
```yaml
<version>: 
    uri: <URI of binary>
    license: <URI of license>
```

You can store your files in the repository. An example layout might look like:

```
/index.yml
/ibm-java-jre-7.0-5.0-x86_64-archive.bin
/ibm-java-jre-7.0-5.0-x86_64-License.html
```

## Usage

[`LibertyBuildpack::Repository::ConfiguredItem`][] is used when dealing with a repository.  It provides a single method to resolve:

* A specific version to the URI containing the binary
* A URI containing the License.

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

You can use the class as follows:

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
Versions are composed of the following four parts: major, minor, micro, and optional qualifier. The version format is: `<major>.<minor>.<micro>[_<qualifier>]`.  See the following table for the requirements of each part:

| Part | Requirement
| ---- | -----------
| Major | numeric
| Minor | numeric
| Micro | numeric
| Optional qualifier | letters, digits, and hyphens with lexical ordering: <ol><li>hyphen</li><li>lowercase letters</li><li>uppercase letters</li><li>digits</li></ol>


## Version Wildcards
Besides declaring a specific version to use, you can also specify a bounded range of versions.  You can append the `+` symbol to a version prefix to use the latest version that begins with the prefix.

| Example | Description
| ------- | -----------
| `1.+`   	| Selects the greatest available version less than `2.0.0`.
| `1.7.+` 	| Selects the greatest available version less than `1.8.0`.
| `1.7.0_+` | Selects the greatest available version less than `1.7.1`. Use this syntax to stay up to date with the latest security releases in a particular version.


[`LibertyBuildpack::Repository::ConfiguredItem`]: ../lib/liberty_buildpack/repository/configured_item.rb

# Setting up your web server

Prerequisites: Download the Liberty Profile runtime and IBM JRE for Java 7.0.

1. Copy the wlp-developers-runtime-8.5.5.3.jar into the `<docroot>/buildpack/wlp` directory.
2. Create `<docroot>/buildpack/wlp/index.yml` which contains  
	
	`# version: uri`  
	`---`  
	`8.5.5_3:` 
	    `uri: http://myhost/buildpack/wlp/wlp-developers-runtime-8.5.5.3.jar` 
	    `license: http://myhost/buildpack/wlp/wlp-developers-runtime-8.5.5.3-License.html` 
	
3. Copy the the ibm-java-jre-7.0-5.0-x86_64-archive.bin into the `<docroot>/buildpack/jre` directory.
4. Create `<docroot>/buildpack/jre/index.yml` which contains  
	
	`# version: uri`  
	`---`  
	`1.7.0:` 
	    `uri: http://myhost/buildpack/jre/ibm-java-jre-7.0-5.0-x86_64-archive.bin`
	    `license: http://myhost/buildpack/jre/ibm-java-jre-7.0-5.0-x86_64-archive-License.html`  
# How to install into your CloudFoundry release
Note: This will not work if the old java buildpack is present

## Option 1 - As an additional submodule

Following these steps will add the Liberty buildpack (or any buildpack) as one of the default buildpacks available.

- Fork the [dea_ng repository](https://github.com/cloudfoundry/dea_ng)
 * `cd dea_ng`
 * `git submodule add <git url for buildpack> buildpacks/vendor/liberty`
 * `git submodule update --init`
 * Edit the URLs for your Liberty binaries
   * Edit [`config/liberty.yml`][liberty.yml]  
     Change the repository_root to point to your webserver
   * Edit [`config/ibmjdk.yml`][ibmjdk.yml]  
     Change the repository_root to point to your webserver
 * `git commit -m "Add liberty buildpack"`
 * `git push`

 <br/>

- Fork the [cf-release repository](https://github.com/cloudfoundry/cf-release)
 * `cd cf-release`
 * `git rm src/dea_next`
 * `git submodule add http://9.38.14.32/fraenkel/dea_ng.git src/dea_next`
 * `git subodule update --init`
 * `git commit -m "Add new dea_next"`
 * `git push`

 <br/>

- Build the release
 * `cd cf-release`
 * `git pull`
 * `git submodule foreach --recursive git submodule sync`
 * `git submodule update --init --recursive`
 * `gem install bosh_cli`
 * `bosh -n create release --force`
     * You may need to install bosh 1.5 or greater  
       `gem install bosh_cli_plugin_micro -v "~> 1.5.0.pre" --source http://s3.amazonaws.com/bosh-jenkins-gems/`

<br/>
- Install CloudFoundry using your favorite mechanism pointing to your new cf-release repository

## Option 2 - Add to the current release
- Fork the [cf-release repository](https://github.com/cloudfoundry/cf-release)
 * `cd cf-release`
 * `git submodule add <git url for buildpack> src/liberty`
 * `git submodule update --init`
 * Edit the URLs for your Liberty binaries
   * Edit [`config/liberty.yml`][liberty.yml]  
     Change the repository_root to point to your webserver
   * Edit [`config/ibmjdk.yml`][ibmjdk.yml]  
     Change the repository_root to point to your webserver
 * `ln -sf ../src/liberty/bosh/packages/liberty packages`
 * `cp src/liberty/bosh/jobs/dea_next/templates/post_install jobs/dea_next/templates`
 * edit jobs/dea_next/spec
		* Add the following line under templates:  
	  	  `post_install: bin/post_install`
	  	* Add the following line under packages:  
	  	  `- liberty`
 * `gem install bosh_cli`
 * `bosh -n create release --force`
     * You may need to install bosh 1.5 or greater  
	   `gem install bosh_cli_plugin_micro -v "~> 1.5.0.pre" --source http://s3.amazonaws.com/bosh-jenkins-gems/`

<br/>
- Install CloudFoundry using your favorite mechanism pointing to your new cf-release repository


# Setting up your Web Server
- Copy the the wlp-developers-runtime-8.5.5.0.jar into the `<docroot>/buildpack/wlp` directory.
- Create `<docroot>/buildpack/wlp/index.yml` which contains  
	
	`# version: uri`  
	`---`  
	`8.5.5.0: http://myhost/buildpack/wlp/wlp-developers-runtime-8.5.5.0.jar`  
	
- Copy the the ibm-java-jre-7.0-5.0-linux-x86_64.tgz into the `<docroot>/buildpack/jre` directory.
- Create `<docroot>/buildpack/jre/index.yml` which contains  
	
	`# version: uri`  
	`---`  
	`1.7.0: http://myhost/buildpack/jre/ibm-java-jre-7.0-5.0-linux-x86_64.tgz`  
	

[liberty.yml]: ../config/liberty.yml
[ibmjdk.yml]: ../config/ibmjdk.yml
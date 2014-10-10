# How to install the Buildpack into your Cloud Foundry release

As a Cloud Foundry administrator, you can install the Liberty Buildpack as an `admin Buildpack`, which can be used by all users in your Cloud Foundry environment. To create the admin Buildpack:

1. Clone the `ibm-websphere-liberty-buildpack` repository to a machine with Ruby installed and Internet connectivity.

1. Customize the buildpack configuration as needed.

   If you are licensed to deploy the buildpack into your environment, you can create a `config/licenses.yml` file that contains the accepted license numbers prior to packaging:

   ```yaml
   ---
   IBM_JVM_LICENSE: <jvm license code>
   IBM_LIBERTY_LICENSE: <liberty license code>
   ```

   After adding the license to the buildpack package, individual applications will not be required to accept the license terms via environment variables.
   
1. In the top-level directory of the cloned repository, run the Rake `package` task to create an admin buildpack:

   ```bash
   bundle exec rake package
   ```

   This task pulls down the Liberty and IBM JRE binaries that are hosted on public IBM sites and packages the binaries  with the Buildpack code in a .zip file in the parent directory. The name of the file consists of the name of the repository directory appended with the shortened identifier of the latest commit. If you are using the default name for the buildpack repository directory, the file name is of the form ibm-websphere-liberty-buildpack-480d2de.zip where 480d2de would be replaced by the latest commit identifier.  


   The rake package task can be customized by providing parameters.  The accepted parameters are _zipfile_, _hosts_, and _version_ in the following order:

   ```bash
   bundle exec rake 'package[zipfile,hosts,version]'
   ```
   
   _zipfile_ is the name of the generated admin buildpack and should include a relative location that is NOT the current directory.  For example, "../my-admin-buildpack.zip" can be specified as the zipfile to generate my-admin-buildpack.zip in the parent directory instead of the default ibm-websphere-liberty-buildpack-480d2de.zip. An example of this usage:
 
   ```bash
   bundle exec rake 'package[../my-admin-buildpack.zip]'
   ```
 
   _hosts_ is a list of sites that the package task should pull binaries from, for inclusion in the admin buildpack.  By default, only binaries from the public IBM site will be pulled. As IBM hosted sites do not include third party binaries, a package parameter should be specified to indicate that third party binaries should be included in the admin buildpack for cases where the admin buildpack will be used in offline mode. Using * will include all the binaries (if the download is possible during the packaging) in the admin buildpack. An example of this usage:
 
   ```bash
   bundle exec rake 'package[,*,]'
   ```
    
   _version_ is the version information that will be displayed when an application is deployed to CloudFoundry using the CF CLI.  By default, the displayed version is the latest commit identifier, such as 480d2de.  An example of the displayed version information when using the default:
 
   ```bash
   -----> Liberty Buildpack Version: 480d2de | git@github.com:cloudfoundry/ibm-websphere-liberty-buildpack.git#480d2de
   ```
 
   Specifying the version to be v1.2.3 in the following example:
  
   ```bash
   bundle exec rake 'package[,,v1.2.3]'
   ```
    
   Results in the output:
  
   ```bash
   -----> Liberty Buildpack Version: v1.2.3 
   ```

1. Install the admin Buildpack using the `cf` client as follows:

   ```bash
   cf create-buildpack ibm-websphere-liberty-buildpack ibm-websphere-liberty-buildpack-480d2de.zip 1
   ```

  In this command:

  * `ibm-websphere-liberty-buildpack` is the name that will be given to the admin buildpack

  * `ibm-websphere-liberty-buildpack-480d2de.zip` is the path to the .zip file that is created by the Rake task

  * `1` is the priority given to the admin Buildpack. The lower the number, the higher the priority. See the Cloud Foundry documentation for further details.

  Result: Users of the Cloud Foundry environment using the Liberty Buildpack do not need to specify the `-b` option in order to use the buildpack directly from GitHub. They must, however, still provide the license information in the manifest unless a `config/licenses.yml` file has been provided as described above.

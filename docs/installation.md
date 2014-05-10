# How to install the Buildpack into your Cloud Foundry release

As a Cloud Foundry administrator, you can install the Liberty Buildpack as an `admin Buildpack` which can be used by all users in your Cloud Foundry environment. To create the admin Buildpack:

1. Clone the `ibm-websphere-liberty-buildpack` repository to a machine with Ruby installed and Internet connectivity.

1. In the top-level directory of the cloned repository, run the Rake `package` task:

   ```bash
   rake package
   ```

   This task pulls down the Liberty and IBM JRE binaries and packages them with the Buildpack code in a .zip file in the parent directory. The name of the file matches the name of the repository directory.  If you are using the default name for the repository direcory, the file is named ibm-websphere-liberty-buildpack.zip.

   If you are licensed to deploy the buildpack into your environment, you can create a `config/licenses.yml` file that contains the accepted license numbers prior to packaging:

   ```yaml
   ---
   IBM_JVM_LICENSE: <jvm license code>
   IBM_LIBERTY_LICENSE: <liberty license code>
   ```

   By adding the license to the buildpack package, individual applications will not be required to accept the license terms via environment variables.

Install the admin Buildpack using the `gcf` client as follows:

```bash
gcf create-buildpack ibm-websphere-liberty-buildpack ibm-websphere-liberty-buildpack.zip 1
```

In this command:

* `ibm-websphere-liberty-buildpack` is the name that will be given to the admin buildpack

* `ibm-websphere-liberty-buildpack.zip` is the path to the .zip file that is created by the Rake task

* `1` is the priority given to the admin Buildpack

Result: Users of the Cloud Foundry environment using the Liberty Buildpack do not need to specify the `--buildpack` option when pushing applications. They must, however, still provide the license information in the manifest as described above.

Note: The admin buildpacks have a higher precedence than the system buildpacks. The Liberty Buildpack will be used in preference to the system Java Buildpack when pushing WAR files.

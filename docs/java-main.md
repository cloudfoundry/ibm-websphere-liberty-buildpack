Java Main Push
========================================

The Java Main container allows a Java application (jar) that contains a class with a main() method to be run.

## Usage
To deploy Java Main applications using the IBM WebSphere Application Server Liberty Buildpack, you are required to accept the IBM JRE license by following these instructions: 

1. Read the current IBM [JVM-License][].
2. Extract the `D/N: <License code>` from the JVM-License.
3. Add the environment variable in the code example, and the extracted license code, to the manifest.yml file in the directory from which you push your application. For more information on the format of the manifest.yml file, see [manifest documentation][]. 

    ```
      env:
        IBM_JVM_LICENSE: <jvm license code>
    ```

After you have set the license acceptance environment variables, use the following command to deploy the application with the IBM WebSphere Application Server Liberty Buildpack:

```bash
cf push <APP-NAME> -p <ARTIFACT> -b https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack.git --no-route
```

[JVM-License]: http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?la_formnum=&li_formnum=L-AWON-8GALN9&title=IBM%C2%AE+SDK%2C+Java-+Technology+Edition%2C+Version+7.0&l=en
[manifest documentation]: http://docs.cloudfoundry.com/docs/using/deploying-apps/manifest.html
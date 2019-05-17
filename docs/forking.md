
IBM WebSphere Application Server Liberty Buildpack
Copyright 2014-2015 the original author or authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
     http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

# Forking the buildpack

To fork the Buildpack and host your own binaries, then complete the following:

1. Fork the [ibm-websphere-liberty-buildpack](https://github.com/cloudfoundry/ibm-websphere-liberty-buildpack).

2. Clone the forked repository to your local machine.

3. Download the wlp-developers-runtime-8.5.5.3.jar from [wasdev.net][].

4. Download the latest IBM JRE for Linux from the [developerWorks Java site][].
  The download will be in an archive .bin format.

5. Copy the binaries to a location that the buildpack will be able to access via HTTP. For details see
  [Repositories][]. For an example see [Setting up your Web Server][]

6. Modify the code in [`config/ibmjdk.yml`][ibmjdk.yml] to point to the JRE.

7. Modify the code in [`config/liberty.yml`][liberty.yml] to point to Liberty.

8. Commit and push the changes

9. You should now be able to deploy applications to your forked buildpack with the following command:
```bash
cf push <APP-NAME> -p <ARCHIVE> -b <URL to forked repository>
```

[wasdev.net]: http://wasdev.net
[developerWorks Java site]: https://www.ibm.com/developerworks/java/jdk/
[Repositories]: util-repositories.md
[Setting up your Web Server]: util-repositories.md#setting-up-your-web-server
[ibmjdk.yml]: ../config/ibmjdk.yml
[liberty.yml]: ../config/liberty.yml

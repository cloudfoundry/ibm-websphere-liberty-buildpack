[//]:# IBM WebSphere Application Server Liberty Buildpack
[//]:# Copyright 2014-2016 the original author or authors.
[//]: #
[//]: # Licensed under the Apache License, Version 2.0 (the "License");
[//]: # you may not use this file except in compliance with the License.
[//]: # You may obtain a copy of the License at
[//]: #
[//]: #      http://www.apache.org/licenses/LICENSE-2.0
[//]: #
[//]: # Unless required by applicable law or agreed to in writing, software
[//]: # distributed under the License is distributed on an "AS IS" BASIS,
[//]: # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
[//]: # See the License for the specific language governing permissions and
[//]: # limitations under the License.

# Troubleshooting


| Error message  | Problem       | Solution  |
| -------------  |:-------------:| --------- |
| The pushed server is incorrectly packaged. Use the command 'server package --include=usr' to package a server. | The pushed server contains binaries which are not allowed. | Package the server without the binaries. To do this, use the server package command with the '--include=usr' option.   |
| You have not accepted the IBM Liberty License. | To use the Liberty buildpack you are required to read the Licenses for Liberty Profile and IBM JVM.|   <br>Visit the following uri: <br>IBM [Liberty-License][] and the current IBM [JVM-License][].<br>Extract the license number (D/N:) and place it inside your manifest file as a ENV property e.g. <code><br>ENV: <br>  IBM_LIBERTY_LICENSE: {License Number}.</code>      |

[Liberty-License]: https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/16.0.0.4/lafiles/runtime/en.html
[JVM-License]: http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?la_formnum=&li_formnum=L-PMAA-A3Z8P2&title=IBM%AE+SDK%2C+Java%99+Technology+Edition%2C+Version+8.0&l=en

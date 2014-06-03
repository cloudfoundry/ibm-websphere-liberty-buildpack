# Troubleshooting


| Error message  | Problem       | Solution  |
| -------------  |:-------------:| --------- |
| The pushed server is incorrectly packaged. Use the command 'server package --include=usr' to package a server. | The pushed server contains binaries which are not allowed. | Package the server without the binaries. To do this, use the server package command with the '--include=usr' option.   |
| You have not accepted the IBM Liberty License. | To use the Liberty buildpack you are required to read the Licenses for Liberty Profile and IBM JVM.|   <br>Visit the following uri: <br>IBM [Liberty-License][] and the current IBM [JVM-License][].<br>Extract the license number (D/N:) and place it inside your manifest file as a ENV property e.g. <code><br>ENV: <br>  IBM_LIBERTY_LICENSE: {License Number}.</code>      |



[Liberty-License]: http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/8.5.5.1/lafiles/runtime//en.html
[JVM-License]: http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?la_formnum=&li_formnum=L-AWON-8GALN9&title=IBM%C2%AE+SDK%2C+Java-+Technology+Edition%2C+Version+7.0&l=en
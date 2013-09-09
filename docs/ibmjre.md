#Repackage the IBM JRE

The IBM JRE that is available on the [developerWorks Java download site][] is available in a
.bin format. The buildpack, however, requires a .tgz archive. Follow these instructions to build a
.tgz archive from the .bin file.

* Upload the .bin file to a directory on your Linux machine

* Ensure that the executable bit is set on the file

```bash
sudo chmod +x ibm-java-jre-7.0-5.0-x86_64-archive.bin
```

* Execute the install

```bash
./ibm-java-jre-7.0-5.0-x86_64-archive.bin
```

* Select the language

* Accept the license

* Accept the default installation location

* Execute the following command to build the .tgz archive

```bash
tar cvfz ibm-java-jre-7.0-5.0-linux-x86_64.tgz ibm-java-x86_64-70
```

[developerWorks Java download site]: https://www.ibm.com/developerworks/java/jdk/
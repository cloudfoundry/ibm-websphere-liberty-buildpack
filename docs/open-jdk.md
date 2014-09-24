# Open JDK
The Open JDK provides Java runtimes from the [OpenJDK][] project. The IBM JDK is the default used with Liberty profile. If you would prefer to use the Open JDK then set the `JVM` environment variable to `openjdk`. For example, add the following to your *manifest.yml* file:

```bash
---
env:
  JVM: openjdk
```

If you are interested in using the IBM JDK please read [IBM JDK](ibm-jdk.md).

[OpenJDK]: http://openjdk.java.net


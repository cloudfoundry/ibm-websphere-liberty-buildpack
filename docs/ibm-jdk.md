# IBM JDK
The IBM JDK is the default used with Liberty profile. You do not need to change the *manifest.yml* file or configure anything else to use the IBM JDK. The behavior is the same as setting the `JVM` environment variable to `ibmjdk`. For example, using the *manifest.yml* file:

```bash
---
env:
  JVM: ibmjdk
```

If you would prefer to use the Open JDK then please read [Open JDK](open-jdk.md).


Tuning the Liberty Profile in the Cloud
========================================

You can tune parameters and attributes of the Liberty profile.

## Tuning the JVM
Tuning the JVM is a most important tuning step whether you configure a development or production environment.
When you tune the JVM for the Liberty profile, create a jvm.options file in your server directory. 
You can specify each of the JVM arguments that you want to use, one option per line. An example of the jvm.options file is as follows:

```
-Xms50m
-Xmx256m
```

For a development environment, you might be interested in faster server startup, so consider setting the minimum heap size to a small value, and the maximum heap size to whatever value is needed for your application. For a production environment, setting the minimum heap size and maximum heap size to the same value can provide the best performance by avoiding heap expansion and contraction.

Tuning the Liberty Profile in the Cloud
========================================

## Tuning the JVM
Tuning the JVM is the most important tuning step whether you configure a development or production environment. To tune the JVM for the Liberty profile:
1. Create a jvm.options file in your server directory.
2. In the jvm.options file, specify each of the JVM arguments that you want to use, one option per line. For example:
```
-Xms50m
-Xmx256m
```

## Tip
* For a development environment, you can tune the heap size for a faster server startup. To do this, set the minimum heap size to a small value, and the maximum heap size to whatever value is needed for your application.
* For a production environment, you can tune the heap size for the best performance by avoiding heap expansion and contraction. To do this, set the minimum heap size and maximum heap size to the same value.

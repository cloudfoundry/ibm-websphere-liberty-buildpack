### How to apply an iFix to the Liberty runtime?

An iFix can be applied to an application using the `.profile.d` feature. 
  * Create the `.profile.d` directory in the root of the application that's being deployed to IBM Cloud. 
  * Create the `.ifixes` directory under the `.profile.d` directory.
  * Place the iFix `.jar` file in the `.profile.d/.ifixes/` directory.
  * Create `ifix.sh` file in the `.profile.d` directory with the following contents (update the `<ifix filename>` accordingly)
  * If the iFix file can cleanly apply against the IBM Cloud version of Liberty, use the following script:

     
```
#!/bin/sh
echo "Applying iFixes"
$HOME/.java/jre/bin/java -jar $HOME/.profile.d/.ifixes/<ifix filename>.jar --installLocation $HOME/.liberty/
     
```
     
  * If the iFix file cannot cleanly apply, use the following script:

     
```
#!/bin/sh
echo "Applying iFixes"
unzip $HOME/.profile.d/.ifixes/<ifix filename>.jar lib/*.jar -d $HOME/.liberty
     
```
  
For example, the contents of the `.profile.d` directory should look like the following:
```
.profile.d/
.profile.d/.ifixes/16003-wlp-archive-IFPI68805.jar
.profile.d/ifix.sh
```

Once you deploy your application, you should see the following message that indicates which iFixes were applied:

```
CWWKF0015I: The server has the following interim fixes active in the runtime: PIXXXXX. For a full listing of installed fixes run: productInfo version --ifixes
```
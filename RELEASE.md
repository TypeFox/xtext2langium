#### Deploy locally
##### Setup your local settings.xml

```
<servers>
    <server>
        <id>OSSRH</id>
        <username>USER_NAME</username>
        <password>PASSWORD</password>
    </server>
</servers>
<!-- Only needed for release deployment --> 
<profiles>
    <profile>
        <id>OSSRH</id>
        <activation>
            <activeByDefault>true</activeByDefault>
        </activation>
        <properties>
            <gpg.executable>/usr/local/bin/gpg</gpg.executable>
            <gpg.keyname>KEY_ID</gpg.keyname>
            <gpg.passphrase>KEY_PASSWORD</gpg.passphrase>
        </properties>
    </profile>
</profiles>
```

##### Deploy a SNAPSHOT

Run `mvn clean deploy`

_Note: Current setup requires Java11_

##### Deploy a RELEASE

Set the new version
`mvn org.eclipse.tycho:tycho-versions-plugin:2.7.5:set-version -DnewVersion=0.1.0`

Start deployment
`mvn clean deploy -P release`

Check the status of the staged repository and release
[oss.sonatype.org](https://oss.sonatype.org/index.html)
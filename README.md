[![Build Xtext2Langium](https://github.com/TypeFox/xtext2langium/actions/workflows/main.yml/badge.svg)](https://github.com/TypeFox/xtext2langium/actions/workflows/main.yml)

# xtext2langium

#### Generator Fragment for MWE2 Workflow

This MWE2 fragment reads your Xtext grammar and converts it to Langium.
If you are using a predefined Ecore model (not generated), it will also be converted to Langium as a type definition file. 


#### How to consume

P2 Repository:
https://typefox.github.io/xtext2langium/download/updates/v0.3.0/

Maven: 
```xml
<dependency>
    <groupId>io.typefox.xtext2langium</groupId>
    <artifactId>io.typefox.xtext2langium</artifactId>
    <version>0.3.0</version>
</dependency>
```

Gradle:
`io.typefox.xtext2langium:io.typefox.xtext2langium:0.3.0`


#### How to use

Add the fragment to you Language configuration in the MWE2 file and
configure the output path.

```js
language = StandardLanguage {
    name = "io.typefox.Example"
    // ... //

    fragment = io.typefox.xtext2langium.Xtext2LangiumFragment {
        outputPath = './langium'
    }
```

After running the workflow you will find the generated Langium output in `./langium` folder.

[![Build Xtext2Langium](https://github.com/TypeFox/xtext2langium/actions/workflows/main.yml/badge.svg)](https://github.com/TypeFox/xtext2langium/actions/workflows/main.yml)

# xtext2langium

#### Generator Fragment for MWE2 Workflow

#### How to consume

P2 Repository:
https://typefox.github.io/xtext2langium/download/updates/main/

Maven: 
```xml
<dependency>
    <groupId>io.typefox.xtext2langium</groupId>
    <artifactId>io.typefox.xtext2langium</artifactId>
    <version>0.1.0</version>
</dependency>
```

Gradle:
`io.typefox.xtext2langium:io.typefox.xtext2langium:0.1.0`


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
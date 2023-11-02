[![Build Xtext2Langium](https://github.com/TypeFox/xtext2langium/actions/workflows/main.yml/badge.svg)](https://github.com/TypeFox/xtext2langium/actions/workflows/main.yml)

# Convert Xtext to Langium

#### Generator Fragment for MWE2 Workflow

This MWE2 fragment reads your Xtext grammar and converts it to Langium.
If you are using a predefined Ecore model (not generated), it will also be converted to Langium as a type definition file. 


#### How to consume

##### P2 Repository
Add the `https://typefox.github.io/xtext2langium/download/updates/v0.4.0/` update site to your `.target` file as an additional location.

```xml
<location includeAllPlatforms="false" includeConfigurePhase="false" includeMode="planner" includeSource="true" type="InstallableUnit">
   <unit id="io.typefox.xtext2langium" version="0.0.0"/>
   <repository location="https://typefox.github.io/xtext2langium/download/updates/v0.4.0/"/>
</location>
```

##### Maven

```xml
<dependency>
    <groupId>io.typefox.xtext2langium</groupId>
    <artifactId>io.typefox.xtext2langium</artifactId>
    <version>0.4.0</version>
</dependency>
```

##### Gradle

```
io.typefox.xtext2langium:io.typefox.xtext2langium:0.4.0
```


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

##### Fragment options


- `outputPath` - Target output folder
- `prefixEnumLiterals` - If `true`, enum literal types will be prefixed with the enum type name to avoid name conflicts with other enum literals. Default is `true`. Example: `enum Color: RED;` will create: `Color returns Color: Color_RED; Color_RED returns string: 'RED';`
- `useStringAsEnumRuleType` - If `true`, Enum types will be handled as strings. Only relevant for generated metamodels. Default is `false`.
- `generateEcoreTypes` - If `true`, types from the Ecore metamodel will also be generated. If `false`, ecore data types will be replaced with Langium data types. Types that are not convertible to Langium built in types will be generated as string. Default is `false`.
- `removeOverridenRules` - In case a rule from the imported grammar was overwritten, Langium will report a duplicate error. If `true`, the super grammar rules will be skipped in favour of the current grammar rules. Default is `false`.

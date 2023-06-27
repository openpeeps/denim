<p align="center">
  <img src="https://github.com/openpeeps/denim/blob/main/.github/denim.png" alt="Denim" width="210px" height="210px"><br>
  Denim - Native NodeJS/BunJS addons powered by Nim<br>👑 Written in Nim language
</p>

<p align="center">
  <code>nimble install denim@#head</code><br><br>
  <a href="https://openpeeps.github.io/denim">API reference</a><br>
  <img src="https://github.com/openpeeps/denim/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/denim/workflows/docs/badge.svg" alt="Github Actions">
</p>

<p align="center">
  <img src="https://github.com/openpeeps/denim/blob/main/.github/denim-cli-screen.png" alt="Denim CLI" width="676px">
</p>

## 😍 Key Features
- [x] Native build via `node-gyp`
- [ ] Native build via `CMake.js`
- [x] Low-level API
- [ ] High-level API
- [x] Open Source | `MIT` License
- [x] Written in 👑 Nim language

## Requirements
- Get the latest Nim version (**Note** Denim works with `choosenim`)
- Install Node.js and `node-gyp`, the native addon build tool
- Install Denim CLI via `nimble`

### CLI
Denim is a hybrid package, you can use it as a CLI for compiling Nim code to `.node` addon via `Nim` + `NodeGYP`

Simply run `denim -h`
```
DENIM 🔥 Native Node/Bun addons powered by Nim language

  build <entry> --release --yes         Nim to Node addon
  publish                               Publish addon to NPM
```


Use Denim as a Nimble task:
```nim
task napi, "Build a .node addon":
  exec "denim build src/myprogram.nim"
```

### Defining a module

Use `init` to define module initialization.
```nim
import denim # import NAPI bindings 
init proc(module: Module) =
  # registering properties and functions here
  # this is similar with javascript `module.exports`
```

### Nim Type to NapiValueType
Use low-level API to convert Nim values to `napi_value` (`NapiValueType`) such as `number`, `string`, `object`, `bool`, and so on.
Use `assert` to check if a low-level function returns a success or failure. [Currently, the following status codes are supported](https://nodejs.org/api/n-api.html#napi_status)

```nim
import denim
init proc(module: Module) =
  module.registerFn(0, "awesome"):
    var str2napi: napi_value
    var str = "Nim is awesome!"
    assert Env.napi_create_string_utf8(str, str.len.csize_t, str2napi.addr) 
    return str2napi
```

Alternatively, use `%*` to auto-convert Nim values to `NapiValueType`.
```nim
let
  a: napi_value = %* "Hey"
  b: napi_value = %* true
assert a.kind == napi_string
assert b.kind == napi_boolean
```

### Exports
Since `v0.1.5`, you can use `{.export_napi.}` pragma to export functions and object properties.

```nim
import denim
import std/json except `%*`

init proc(module: Module): # the name `module` is required
  proc hello(name: string) {.export_napi} =
    ## A simple function from Nim
    return %* "Hello, " & args.get("name")

  proc callNimFn(): object {.export_napi} =
    ## Return a JSON object
    var data: JsonNode = newJObject()
    data["say"] = newJString("Hello!")
    # convert `data` to napi_string using `%*`
    # then, call native JSON.parse() 
    return napiCall("JSON.parse", [%* $(data)])

  var awesome {.export_napi.} = "Nim is Awesome!"
```

Calling a function/property from Node/Bun
```js
const app = require('myaddon.node')
console.log(app.hello("World!"))       // Hello, World!
console.log(app.awesome)               // Nim is Awesome!

console.log(app.callNimFn().say)     // Hello!
```

# Built-in type checker
```js
app.hello()
```

```
/*
 * A simple function from Nim
 * @param {string} name
 * @return {string}
 */
Type mismatch parameter: `name`. Got `undefined`, expected `string`
```


## Real-World Examples
- **Tim Engine** is a powerful template engine and markup language written in Nim. [Here is the code for building Tim to Node/Bun via NAPI](https://github.com/openpeeps/tim/blob/main/src/tim.nim#L8-L133), 
- **Bro**, a better stylesheet language, alternative to SassC, DartSass, SassJS. Written in Nim. [Here is the code](https://github.com/openpeeps/bro/blob/main/src/bro.nim#L6)

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/denim/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/denim/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
Denim | MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps)<br>
Thanks to [Andrew Breidenbach](https://github.com/AjBreidenbach) and [Andrei Rosca](https://github.com/andi23rosca) for their work.<br>

Copyright &copy; 2023 OpenPeeps & Contributors &mdash; All rights reserved.

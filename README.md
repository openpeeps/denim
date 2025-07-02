<p align="center">
  Denim - Native NodeJS/BunJS addons powered by Nim<br>👑 Written in Nim language
</p>

<p align="center">
  <code>nimble install denim</code><br><br>
  <a href="https://openpeeps.github.io/denim">API reference</a><br>
  <img src="https://github.com/openpeeps/denim/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/denim/workflows/docs/badge.svg" alt="Github Actions">
</p>

## 😍 Key Features
- [x] CLI build via Nim + `node-gyp` or CMake.js (faster)
- [ ] CLI publish to NPM
- [x] Low-level API
- [x] High-level API
- [x] Open Source | `MIT` License
- [x] Written in 👑 Nim language

## Requirements
- Nim (latest / via `choosenim`)
- Node (latest) and `node-gyp` or CMake.js

### CLI
Denim is a hybrid package, you can use it as a CLI for compiling Nim code to `.node` addon via `Nim` + `NodeGYP` and as a library for importing NAPI bindings.

Simply run `denim -h`
```
DENIM 🔥 Native Node/BunJS addons powered by Nim

  build <entry> <links> --cmake --yes --verbose          Build Nim project to a native NodeJS addon
  publish                                                Publish addon to NPM (requires npm cli)
```

Use Denim as a Nimble task:
```nim
task napi, "Build a .node addon":
  exec "denim build src/myprogram.nim"
```

Want to pass custom flags to Nim Compiler? Create a `.nims` file:
```nim
when defined napibuild:
  # add some flags
```

> __Note__ Check fully-working examples in [/tests](https://github.com/openpeeps/denim/tree/main/tests)

### Defining a module

Use `init` to define module initialization.
```nim
when defined napibuild:
  # optionally, you can use `napibuild` flag to wrap your code
  # this flag is set when compiling via `denim build src/myprogram.nim` 
  import denim # import NAPI bindings 
  init proc(module: Module) =
    # registering properties and functions here
    # this is similar with javascript `module.exports`
elif isMainModule:
  echo "just a normal nim program"
```

### Nim Type to NapiValueType
Use low-level API to convert Nim values to `napi_value` (`NapiValueType`).
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

init proc(module: Module): # the name `module` is required
  proc hello(name: string) {.export_napi} =
    ## A simple function from Nim
    return %*("Hello, " & args.get("name").getStr)

  var awesome {.export_napi.} = "Nim is Awesome!"
```

Calling a function/property from Node/Bun
```js
const app = require('myaddon.node')
console.log(app.hello("World!"))       // Hello, World!
console.log(app.awesome)               // Nim is Awesome!
```

### Built-in type checker
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
- **Tim Engine** &mdash; A template engine. [GitHub](https://github.com/openpeeps/tim)
- **Bro** &mdash; A fast stylesheet language, alternative to SassC, DartSass. [GitHub](https://github.com/openpeeps/bro)
- **HappyX** &mdash; Macro-oriented asynchronous web-framework written in Nim. [GitHub](https://github.com/HapticX/happyx)

### Todo
- Option to link external C Headers/libraries
- Extend High-level API with compile-time functionality. 

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/denim/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/denim/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)

### 🎩 License
Denim | MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps)<br>
Thanks to [Andrew Breidenbach](https://github.com/AjBreidenbach) and [Andrei Rosca](https://github.com/andi23rosca) for their work.<br>

Copyright &copy; 2023 OpenPeeps & Contributors &mdash; All rights reserved.

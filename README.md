<p align="center">
  <img src="https://github.com/openpeeps/denim/blob/main/.github/denim.png" alt="Denim" width="170px"><br>
  Denim - Native NodeJS/BunJS addons powered by Nim<br>👑 Written in Nim language
</p>

<p align="center">
  <code>nimble install denim</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/denim">API reference</a><br>
  <img src="https://github.com/openpeeps/denim/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/denim/workflows/docs/badge.svg" alt="Github Actions">
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

### Defining a module

Use `init` to define module initialization.
```nim
init proc(module: Module) =
  # registering properties and functions here
```

### Registering module exports
Export properties and functions using `registerFn()` for functions and `register()` for properties

```nim
init proc(module: Module) =
  module.registerFn(0, "hello"):
    # fn body
```

### Check function arguments
```nim
init proc(module: Module) =
  module.registerFn(3, "setUsername"):
    # throw NAPI error when
    # mismatch arg types / receive less args than expected 
    if not Env.expect(args, "MyProgram",
      ("name", napi_string),
      ("email", napi_string),
      ("?age", napi_number) # prefix with `?` to set as optional arg
    ): return
    # do the do
```

## Examples
```nim
init proc(module: Module) =
  module.registerFn(1, "hello"):
    # access function arguments using `args` seq
    # use `%*` operator to convert Nim types to `napi_value`
    return %* "Yay! " & args[0].getStr
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

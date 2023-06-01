<p align="center">
  <img src="https://github.com/openpeeps/denim/blob/main/.github/denim.png" alt="Denim" width="170px"><br>
  Denim - Native NodeJS/BunJS addons powered by Nim language<br>👑 Written in Nim
</p>

<p align="center">
  <code>nimble install denim</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/denim">API reference</a><br>
  <img src="https://github.com/openpeeps/denim/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/denim/workflows/docs/badge.svg" alt="Github Actions">
</p>

## 😍 Key Features
- [x] Open Source | `MIT` License
- [x] Written in 👑 Nim language

## Requirements
- Get the latest Nim version (**Note** Denim works with `choosenim`)
- Install Node.js and `node-gyp`, the native addon build tool
- Install Denim CLI via `nimble`

## Example

Here we'll use [nyml package](https://github.com/openpeeps/nyml) to build a native nodejs yaml parser

My `yaml.nim`
```nim
import denim/napi/napibindings
import nyml except `%*`

init proc(module: Module) =
  module.registerFn(1, "parse"):
    let yamlContent = args[0].getStr
    return napiCall("JSON.parse", [
      %* yaml(yamlContent).toJsonStr
    ])
```

Magically run
```denim build yaml.nim```

Here is my JS code.
```js
const {parse} = require('./yaml.node')
const sample = "email: test@example.com"

let obj = parse(sample)

console.log(obj)
console.log(obj.email == "test@example.com")
```

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/denim/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/denim/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)
- 🥰 [Donate via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C)

### 🎩 License
Denim | MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps)<br>
Thanks to [Andrew Breidenbach](https://github.com/AjBreidenbach) and [Andrei Rosca](https://github.com/andi23rosca) for their work.<br>

Copyright &copy; 2023 OpenPeeps & Contributors &mdash; All rights reserved.

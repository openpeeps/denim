<p align="center">
  Denim - Native NodeJS/BunJS addons powered by Nim<br>👑 Written in Nim language
</p>

<p align="center">
  <code>nimble install denim</code><br><br>
  <a href="https://openpeeps.github.io/denim">API reference</a><br>
  <img src="https://github.com/openpeeps/denim/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/denim/workflows/docs/badge.svg" alt="Github Actions">
</p>

## 😍 Key Features
- CLI build via Nim + internal CMake driver (faster, no npm deps) or `node-gyp`
- Low-level & High-level API

## Requirements
- Nim (latest / via `choosenim`)
- Node (latest) and `node-gyp`, or just `cmake` for `--cmake` builds (no npm packages needed)

### CLI
Denim is a hybrid package, you can use it as a CLI for compiling Nim code to `.node` addon
via `Nim` + internal CMake driver or `node-gyp`, and as a library for importing NAPI bindings.

`denim build -h` shows the build flags:
```
denim 0.2.1 - Nim code to Node.js/Bun.js in seconds via NAPI

MIT license | Made by Humans from OpenPeeps
  https://github.com/openpeeps/denim

usage: denim <command> [options]

commands:
  build <nim:file>      build a native .node addon from Nim

build options:
  -y                      remove an existing denim_build directory without asking
  --cmake                 use the internal CMake driver (faster, no npm deps)
  --generator:<name>      CMake generator (default: Ninja if available, else Unix Makefiles)
  --nodedir:<dir>         Node headers directory (or NODE_HEADERS env)
  --includeDirs:<list>    extra -I header search dirs
  --includeFiles:<list>   extra .c files to compile
  --defines:<list>        extra -D defines
  --cflags:<flags>        extra C compiler flags
  --linkFlags:<flags>     extra linker flags
  -r                      release build (-d:release --opt:speed)
  --verbose               print the Nim and CMake/node-gyp output
  -h, --help              show this help

options:
  -h, --help            show this help
  --version             show version
```

### Build flags

Denim reads your Nim code first: `{.compile.}` sources are compiled automatically,
and `{.passC.}` / `{.passL.}` pragmas reach the C compiler and linker without any
flags. The CLI flags below are only overrides for things Nim does not track.
Every flag accepts either a comma-separated string or a stringified JSON array:

```
--includeDirs '["/opt/foo/include","/opt/bar/include"]'
--defines 'FOO=1,BAR="baz"'
```

- `--cmake` — build with the internal CMake driver instead of node-gyp (faster, recommended). Only needs a `cmake` binary and local Node headers (`node_api.h`); no `cmake-js` npm package required.
- `--generator` — CMake generator override, e.g. `--generator "Unix Makefiles"`. Default: `Ninja` when available, else `Unix Makefiles`.
- `--nodedir` — Node headers override (also accepts `NODE_HEADERS` env). Default: auto-detected from the running `node` binary and well-known include paths.
- `-y` — remove an existing `denim_build` directory without asking.
- `-r` — release build (`-d:release --opt:speed`).
- `--verbose` — print the Nim and CMake/node-gyp output.
- `--includeDirs` — extra `-I` header search dirs. Seldom needed, `{.passC: "-I...".}` is forwarded automatically.
- `--includeFiles` — extra `.c` files to compile. Seldom needed, `{.compile: "foo.c".}` files are picked up automatically.
- `--defines` — extra `-D` defines, e.g. `--defines 'FOO=1,BAR="baz"'`. Prefer `{.passC: "-DFOO=1".}` in Nim.
- `--cflags` — extra C compiler flags, e.g. `--cflags '-O2 -std=c99'`. Prefer `{.passC.}` in Nim.
- `--linkFlags` — extra linker flags, e.g. `--linkFlags '-L/opt/lib -lssl'`. Prefer `{.passL.}` in Nim.

### How `--cmake` works

No `cmake-js` npm package is needed, only a `cmake` binary (`3.15+`) and a C++
compiler. Denim drives CMake itself:

1. Runs `nim c --compileOnly` and reads the nimcache JSON, forwarding
   `{.compile.}` sources, `{.passC.}` include dirs/defines/flags, and
   `{.passL.}` link flags into a generated `CMakeLists.txt`.
2. Locates local Node headers (`node_api.h`) — override with `--nodedir`
   (or `NODE_HEADERS` env). Otherwise it checks the running `node` install
   prefix, `which node`, `/usr/local`, `/usr`, `/opt/homebrew`, `/opt/local`,
   and the `~/.node-gyp` caches. Nothing is downloaded.
3. Configures with `Ninja` when available, else `Unix Makefiles`
   (override with `--generator`), then builds
   `denim_build/build/Release/<name>.node` and moves it to `bin/`.

Omit `--cmake` to build with `node-gyp` instead (unchanged behavior, requires
`node-gyp` on `PATH`). On Windows the internal driver is not supported yet —
omit `--cmake` there as well.

```
denim build myaddon.nim --cmake -y
node -e "console.log(require('./bin/myaddon.node').add(2, 3))"
# 5
```

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


### Vendoring C: Magic 8-Ball

The classic Nim idiom of shipping C sources with `{.compile.}` just works.
This example wraps a tiny C Magic 8-Ball and asks it questions from Node:

`vendor/magic8ball.h`
```c
#ifndef MAGIC8BALL_H
#define MAGIC8BALL_H
const char* magic8ball_ask(unsigned int seed);
#endif
```

`vendor/magic8ball.c`
```c
#include "magic8ball.h"
#ifndef NUM_ANSWERS
#error "NUM_ANSWERS not defined - pass it via {.passC.}"
#endif
#if NUM_ANSWERS != 8
#error "NUM_ANSWERS out of sync with the answers table"
#endif
static const char* answers[] = {
  "It is certain", "Without a doubt", "Ask again later",
  "Cannot predict now", "Don't count on it", "My sources say no",
  "Signs point to yes", "Very doubtful"
};
const char* magic8ball_ask(unsigned int seed) {
  return answers[seed % NUM_ANSWERS];
}
```

`vendor/magic.nim`
```nim
import std/os
const vendorDir = currentSourcePath().parentDir()
{.passC: "-I\"" & vendorDir & "\"".}
{.passC: "-DNUM_ANSWERS=8".}
{.compile: "magic8ball.c".}
{.push importc, cdecl, header: "magic8ball.h".}
proc magic8ball_ask(seed: cuint): cstring
{.pop.}
proc ask*(seed: int): string = $magic8ball_ask(seed.cuint)
```

`myaddon.nim`
```nim
import vendor/magic
import denim
init proc(module: Module) =
  proc ask8ball(seed: int): string {.export_napi.} =
    return %* ask(args.get("seed").getInt)
```

Build it and shake the ball:
```
denim build myaddon.nim --cmake -y
node -e "const m = require('./bin/myaddon.node'); console.log(m.ask8ball(42))"
# Ask again later
```

Denim forwards the vendored `magic8ball.c` and the `-I`/`-DNUM_ANSWERS=8`
flags into the CMake build. Without them the build would fail on
`#include "magic8ball.h"` or on the `#error` guards, try removing the
`{.passC.}` lines to see it break.

### Linking a dynamic library: zlib

System libraries need no vendoring, just `{.passL.}`. Denim picks it up from
the Nim build and links it, no `--linkFlags` needed. This addon roundtrips a
string through zlib's `compress`/`uncompress`:

`myaddon.nim`
```nim
{.passL: "-lz".}
{.push importc, header: "<zlib.h>".}
proc compressBound(sourceLen: culong): culong
proc compress(dest: cstring, destLen: ptr culong,
              source: cstring, sourceLen: culong): cint
proc uncompress(dest: cstring, destLen: ptr culong,
                source: cstring, sourceLen: culong): cint
{.pop.}

proc roundtrip*(s: string): string =
  var cbuf = newString(compressBound(s.len.culong))
  var cwritten = cbuf.len.culong
  if compress(cbuf.cstring, addr cwritten, s.cstring, s.len.culong) != 0:
    raise newException(ValueError, "compress failed")
  var ubuf = newString(s.len + 1)
  var uwritten = ubuf.len.culong
  if uncompress(ubuf.cstring, addr uwritten, cbuf.cstring, cwritten) != 0:
    raise newException(ValueError, "uncompress failed")
  ubuf.setLen(uwritten)
  return ubuf

import denim
init proc(module: Module) =
  proc zroundtrip(input: string): string {.export_napi.} =
    return %* roundtrip(args.get("input").getStr)
```

```
denim build myaddon.nim --cmake -y
node -e "console.log(require('./bin/myaddon.node').zroundtrip('Hello from zlib!'))"
# Hello from zlib!
```

The generated build links `-lz` automatically. Only reach for
`--linkFlags '-L/opt/lib -lfoo'` when the library is invisible to Nim,
e.g. a path `{.passL.}` cannot express.

### Minimal C binding

The smallest possible roundtrip: one C function, one Nim wrapper, one
exported addon function.

`vendor/mini.h`
```c
#ifndef MINI_H
#define MINI_H
int mini_add(int a, int b);
#endif
```

`vendor/mini.c`
```c
#include "mini.h"
int mini_add(int a, int b) { return a + b; }
```

`vendor/mini.nim`
```nim
import std/os
const vendorDir = currentSourcePath().parentDir()
{.passC: "-I\"" & vendorDir & "\"".}
{.compile: "mini.c".}
{.push importc, cdecl, header: "mini.h".}
proc mini_add(a, b: cint): cint
{.pop.}
proc add*(a, b: int): int = mini_add(a.cint, b.cint).int
```

`myaddon.nim`
```nim
import vendor/mini
import denim
init proc(module: Module) =
  proc add(a: int, b: int): string {.export_napi.} =
    return %* $(add(args.get("a").getInt, args.get("b").getInt))
```

Copy this skeleton whenever you need a single C helper inside an addon,
then grow toward the 8-ball pattern once you need headers and defines.

## Real-World Examples
- **Tim Engine** &mdash; A template engine. [GitHub](https://github.com/openpeeps/tim)
- **Bowdy** &mdash; A fast stylesheet language, alternative to SassC, DartSass. [GitHub](https://github.com/openpeeps/bowdy)
- **HappyX** &mdash; Macro-oriented asynchronous web-framework written in Nim. [GitHub](https://github.com/HapticX/happyx)
- **OpenParser** &mdash; A collection of tiny parsers and dumpers. CSV, TOML, YAML, RSS, BSON, FBE, DotEnv, Regex, SQL, Gettext (po/mo) and more! [GitHub](https://github.com/openpeeps/openparser)
- **DROP YOUR PROJECT HERE!** 👉 [File an Issue](https://github.com/openpeeps/denim/issues)

### Todo
- Option to link external C Headers/libraries
- Extend High-level API with compile-time functionality. 

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/denim/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/denim/fork)

### 🎩 License
Denim | MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps)<br>
Thanks to [Andrew Breidenbach](https://github.com/AjBreidenbach) and [Andrei Rosca](https://github.com/andi23rosca) for their work.<br>

Copyright &copy; 2026 OpenPeeps & Contributors &mdash; All rights reserved.

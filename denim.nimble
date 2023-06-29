# Package

version       = "0.1.6"
author        = "George Lemon"
description   = "DENIM - Nim code to Bun.js/Node.js in seconds via NAPI"
license       = "MIT"
srcDir        = "src"
bin           = @["denim"]
binDir        = "bin"
installExt    = @["nim"]

# Dependencies
requires "nim >= 1.6.8"
requires "kapsis#head"

import ospaths
let path = getHomeDir() & ".nimble/bin"

task dev, "Compile denim":
  exec "nim c --gc:arc -d:denimcli -o:" & path & "/denim src/denim.nim"

task docgenx, "Build documentation website":
  exec "nim doc --index:on -d:napibuild --project --git.url:https://github.com/openpeeps/denim --git.commit:main src/denim.nim"
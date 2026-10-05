# Package

version       = "0.2.1"
author        = "George Lemon"
description   = "DENIM - Nim code to Bun.js/Node.js in seconds via NAPI"
license       = "MIT"
srcDir        = "src"
bin           = @["denim"]
binDir        = "bin"
installExt    = @["nim"]
installDirs   = @["denim"]

# Dependencies
requires "nim >= 1.6.8"
requires "kapsis >= 0.4.3"

import ospaths
let path = getHomeDir() & ".nimble/bin"

task dev, "Compile denim":
  # exec "nim c --gc:arc -d:denimcli -o:" & path & "/denim src/denim.nim"
  exec "nimble build -d:denimcli"

task docgenx, "Build documentation website":
  exec "nim doc --index:on -d:napibuild --project --git.url:https://github.com/openpeeps/denim --git.commit:main src/denim.nim"

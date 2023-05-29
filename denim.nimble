# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "DENIM - Nim code to Bun.js/Node.js in seconds via NAPI"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["denim"]

# Dependencies
requires "nim >= 1.6.8"
requires "kapsis"

import ospaths
let path = getHomeDir() & ".nimble/bin"

task dev, "Compile denim":
  exec "nim c --gc:arc -o:" & path & "/denim src/denim.nim"

task prod, "Compile denim":
  exec "nim c --gc:arc -d:release -d:danger --opt:size -o:" & path & "/denim src/denim.nim"
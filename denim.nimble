# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Nim code to Bun.js/Node.js in seconds via NAPI"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6.8"
requires "kapsis"

import ospaths
let path = getHomeDir() & "/.nimble/bin"

after install:
  exec "nim c --gc:arc -d:release -d:danger --opt:size -o:" & path & "/denim src/denim.nim"

task dev, "Compile denim":
  exec "nim c --gc:arc -o:" & path & "/denim src/denim.nim"

task prod, "Compile denim":
  exec "nim c --gc:arc -d:release -d:danger --opt:size -o:" & path & "/denim src/denim.nim"
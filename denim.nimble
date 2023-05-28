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

before install:
  let path = getHomeDir() & "/.nimble/bin"
  exec "nim c --gc:arc -d:release -d:danger --opt:size -o:" & path & "/denim src/denim.nim"

task dev, "Compile denim":
  exec "nim c --gc:arc -o:./bin/denim src/denim.nim"

task prod, "Compile denim":
  exec "nim c --gc:arc -d:release -d:danger --opt:size -o:./bin/denim src/denim.nim"
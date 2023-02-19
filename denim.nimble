# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Native NodeJS addons powered by Nim language"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6.8"
requires "klymene"

task dev, "Compile denim":
  exec "nim c --gc:arc -o:./bin/denim src/denim.nim"

task prod, "Compile denim":
  exec "nim c --gc:arc -d:release -d:danger --opt:size -o:./bin/denim src/denim.nim"
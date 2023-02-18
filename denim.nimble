# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Native NodeJS addons powered by Nim language"
license       = "MIT"
srcDir        = "src"
bin           = @["denim"]
binDir        = "bin"

# Dependencies
requires "nim >= 1.6.8"
requires "klymene"

task dev, "Compile denim":
  exec "nimble build --gc:arc"

task prod, "Compile denim":
  exec "nimble build --gc:arc -d:release -d:danger --opt:size"
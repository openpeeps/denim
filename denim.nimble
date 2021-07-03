# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Write native NodeJS addons powered by Nim"
license       = "MIT"
srcDir        = "src"
bin           = @["denim"]

# Dependencies

requires "nim >= 1.4.8"
requires "clymene >= 0.6.8"
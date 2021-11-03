# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Write native NodeJS addons powered by Nim"
license       = "MIT"
srcDir        = "src"
bin           = @["denim"]
binDir        = "bin"

# Dependencies
requires "nim >= 1.4.8"
requires "klymene"
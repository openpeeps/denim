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

task dev, "Compile denim":
    echo "\n✨ Compiling... " & $version & "\n"
    exec "nimble build --gc:arc -d:useMalloc"

task prod, "Compile denim":
    echo "\n✨ Compiling... " & $version & "\n"
    exec "nimble build --gc:arc -d:release -d:useMalloc --opt:size --spellSuggest"
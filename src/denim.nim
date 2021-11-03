#
# Denim is CLI toolkit for creating powerful
# native NodeJS addons written in Nim language.
# 
# Copyright (c) 2021 George Lemon from OpenPeep
#

import klymene
import denim/commands/[init, compile]
from strutils import `%`

const version = "0.1.0"
const binName = "psy"

let sheet = """
Denim 🔥 Create powerful native NodeJS addons powered by Nim language.

Usage:
    $1 new <project>...                  # Invoke "nimble init" #
    $1 build <entry> [--release]         # Compile Nim project to a native NodeJS addon #

Options:
    -h --help        Show this screen.
    -v --version     Show version.
""" % [binName, version, "\e[1mUsage:\e[0m", "\e[1mOptions:\e[0m"]

let args = docopt(sheet, version=version, binaryName=binName)

if isCommand("new", args):          init.runCommand()
elif isCommand("build", args):      compile.runCommand(args["<entry>"])

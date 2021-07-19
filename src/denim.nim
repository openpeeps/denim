import strutils
import clymene
import denim/commands/[init, compile]

# Denim is a CLI tool for creating native NodeJS addons written in Nim.
# Fully written in Nim, powered by Klymene CLI Toolkit (a fork of docopt nim).
# Released "as it is" under MIT license.

let sheet = """
Denim 🔥 Create powerful native NodeJS addons powered by Nim.

Usage:
    denim new <project>...                  # Create a new Denim project by invoking "nimble init" #
    denim build <entry> [--release]         # Compile your Nim project to a native NodeJS addon. Use "release" for compiling release version. #
    denim (-h | --help)
    denim (-v | --version)

Options:
    -h --help        Show this screen.
    -v --version     Show version.
"""

let args = docopt(sheet, version = "Denim 0.1.0")

if args["new"]:
    echo init.runNewCmd(args)
elif args["build"]:
    echo compile.runCompileCmd(args)
import strutils
import clymene
import denim/commands/[init, compile]

let sheet = """
Denim 🔥 Write native NodeJS addons powered by Nim.
For more info https://github.com/georgelemon/denim

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
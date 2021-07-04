import strutils
import clymene
import denim/commands/[init, compile]

let sheet = """
Denim 🧿 Write native NodeJS addons powered by Nim.

Usage:
    denim new <project>...  # Create a new Denim project invoking "nimble init" #
    denim build             # Compile your Nim project to NodeJS native addon #
    denim (-h | --help)
    denim --version

Options:
    -h --help     Show this screen.
    --version     Show version.
"""

let args = docopt(sheet, version = "Denim 0.1.0")

if args["new"]:
    echo init.runNewCmd(args)
if args["build"]:
    echo compile.runCompileCmd(args)
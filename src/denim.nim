import klymene
import denim/commands/[init, compile]

from strutils import `%`
when isMainModule:
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

    let args = newCommandLine(sheet, version=version, binaryName=binName)

    if isCommand("new", args):          init.runCommand()
    elif isCommand("build", args):      compile.runCommand(args["<entry>"])

# import klymene
# import commands/[newCommand, buildCommand]

# about:
#     "Denim 🔥 Create powerful native NodeJS addons powered by Nim language."
#     version "0.1.0"

# commands:
#     $ "new" <project>               "Create a new Nimble project (Invoke `nimble init`)"
#     $ "build" <entry> --release     "Build Nim project to a native NodeJS addon"

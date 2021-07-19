import os, json, tables, strutils, sequtils
import ../utils
from clymene/util import cmd, isEmptyDir
from clymene/cli import confirm, printInfo

proc getNodeGypConfig(release: bool = false): JsonNode = 
    # Create a configuration for node gyp
    # https://nim-by-example.github.io/json/
    let config = %* {
        "target_name": "main",
        "include_dirs": [
            utils.getNimPath()
        ],
        "cflags": release == true ? %*["-w", "-O3", "-fno-strict-aliasing"] ! %*["-w"],
        "linkflags": ["-ldl"]
    }

    return config

proc runCompileCmd*(args: Table[system.string, system.any]): string =
    ## Compile project to source code by using Nim compiler
    # https://nim-lang.org/docs/nimc.html
    var current_dir = os.getCurrentDir()
    var addonPathDirectory = utils.getPath(current_dir, "/example")
    var cachePathDirectory = addonPathDirectory&"/nimcache"
    var entryFile = $(args["<entry>"])

    if not entryFile.endsWith(".nim"):
        echo cli.printInfo("Entry file should be the main '.nim' file of your project", "ℹ")
        return
    else:
        echo "Start compiling $#...".format(entryFile)

    # checking if cache directory contains any files from previous compilation
    if isEmptyDir(addonPathDirectory) == false:
        echo printInfo("Directory is not empty: " & addonPathDirectory)
        var confirmedDeletion = cli.confirm("Do you want to remove previous compilation?")
        if confirmedDeletion == false:
            return

    var isRelease = false
    var build_flag = isRelease ? "-d:release" ! "--embedsrc"
    var getMainFilePath = current_dir

    # Runs the nim compiler on the entry file and creates the equivalent C files in
    # nimcache to be used by node-gyp for building the node addon.
    var cmdCompiler = cmd("nim", [
        "c",
        "--nimcache:"&cachePathDirectory,
        build_flag,
        "--compileOnly",
        "--noMain",
        "--warnings:off",
        utils.getPath(current_dir, "/src/denim/$#".format(entryFile))
    ])

    # Once compiled will get the generated files from nimcache directory.
    # We care about the source C files that node-gyp will
    # have to know about. We can get them from the json file's
    # compile property that has a list of the C files.
    echo cli.printInfo("Denim sucessfully compiled your Nim project to C")
    echo cli.printInfo("Now, invoke node-gyp and compile source code to native NodeJS")

    var gyp = %* {
        "targets": [getNodeGypConfig()]
    }

    var jsonConfigPath = cachePathDirectory & "/" & entryFile.replace(".nim", ".json")
    var jsonConfigContents = parseJson(readFile(jsonConfigPath))
    # create a new Json Array with path of the source files
    var jarr = json.newJArray()
    for elem in items(jsonConfigContents["compile"].elems):
        jarr.add(newJString(elem[0].getStr().replace(addonPathDirectory&"/", "")))
    gyp["targets"][0]["sources"] = %* jarr

    writeFile(addonPathDirectory & "/binding.gyp", $(gyp))

    cmd("node-gyp", [
        "rebuild", "--directory="&addonPathDirectory
    ])

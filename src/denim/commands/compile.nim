import os, json, tables, strutils
import ../utils
from klymene/util import cmd, cmdExec, isEmptyDir
from klymene/cli import promptConfirm, displayInfo
from klymene import Value, `$`

proc getNodeGypConfig(release: bool = false): JsonNode = 
    let config = %* {
        "target_name": "main",
        "include_dirs": [
            utils.getNimPath()
        ],
        "cflags": release == true ? %*["-w", "-O3", "-fno-strict-aliasing"] ! %*["-w"],
        "linkflags": ["-ldl"]
    }

    return config

proc runCommand*(inputFile: Value) =
    ## Compile project to source code by using Nim compiler
    # https://nim-lang.org/docs/nimc.html
    var current_dir = os.getCurrentDir()
    var addonPathDirectory = utils.getPath(current_dir, "/denim_build")
    var cachePathDirectory = addonPathDirectory&"/nimcache"
    var entryFile = $inputFile

    if not entryFile.endsWith(".nim"):
        cli.displayInfo("Entry file should be the main '.nim' file of your project", "ℹ")
        return
    cli.displayInfo("Start compiling $#...".format(entryFile))

    # checking if cache directory contains any files from previous compilation
    if isEmptyDir(addonPathDirectory) == false:
        cli.displayInfo("Directory is not empty: " & addonPathDirectory)
        var confirmedDeletion = cli.promptConfirm("Are you sure you want to remove contents?")
        
        if confirmedDeletion == false:
            cli.displayInfo("Canceled compilation")
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
    cli.displayInfo("Denim sucessfully compiled your Nim project to C")
    cli.displayInfo("Invoke node-gyp and compile source code to native .node addon")

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

    writeFile(addonPathDirectory & "/binding.gyp", pretty(gyp, 4))

    # Inoke Node Gyp library for bundling to Node
    echo cmd("node-gyp", [
        "rebuild", "--directory="&addonPathDirectory
    ])

    # Once bundled, we can navigate to release directory, retrieve the .node file
    # and bring to build directory from root project.
    let binaryNodePath = utils.getPath(current_dir, "/denim_build/build/Release/main.node")
    let buildsDirectory = current_dir & "/examples/builds"
    let binaryTargetPath = buildsDirectory & "/" & entryFile.replace(".nim", ".node")

    # Bail if .node file path could not be found
    if os.fileExists(binaryNodePath) == false:
        echo "Could not find the .node file. Try build again"
    else:
        # Create 'builds' to place the .node addon
        # Once built, will move .node addon from source to 'builds' dir
        if os.existsOrCreateDir(buildsDirectory):
            echo "Creating builds directory"
        os.moveFile(binaryNodePath, binaryTargetPath)
        echo "Done!"

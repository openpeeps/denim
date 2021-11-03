import os, json, tables, strutils
import ../utils
from klymene/util import cmd, cmdExec, isEmptyDir
from klymene/cli import promptConfirm, display
from klymene import Value, `$`

proc getNodeGypConfig(release: bool = false): JsonNode = 
    return %* {
        "target_name": "main",
        "include_dirs": [
            utils.getNimPath()
        ],
        "cflags": if release: %*["-w", "-O3", "-fno-strict-aliasing"] else: %*["-w"],
        "linkflags": ["-ldl"]
    }

proc runCommand*(inputFile: Value) =
    ## Compile project to source code by using Nim compiler
    # https://nim-lang.org/docs/nimc.html
    var
        currDir = os.getCurrentDir()
        addonPathDirectory = utils.getPath(currDir, "/denim_build")
        cachePathDirectory = addonPathDirectory & "/nimcache"
        path = os.splitPath($inputFile)
        entryFile = path.tail

    if not entryFile.endsWith(".nim"):
        display("Entry file should be the main '.nim' file of your project", "ℹ", indent=2)
        quit()
    display("Start compiling $# ...".format(entryFile), indent=2, br="both")

    # checking if cache directory contains any files from previous compilation
    if isEmptyDir(addonPathDirectory) == false:
        display("Directory is not empty: " & os.splitPath(addonPathDirectory).tail, indent=2, br="after")
        if not cli.promptConfirm("👉 Are you sure you want to remove contents?"):
            display("Canceled", indent=2, br="after")
            quit()

    var isRelease = false
    var build_flag = if isRelease: "-d:release" else: "--embedsrc"

    display("🔥 Nim Compiler output", indent=2, br="both")
    echo cmd("nim", [
        "c",
        "--nimcache:"&cachePathDirectory,
        build_flag,
        "--compileOnly",
        "--noMain",
        "--warnings:off",
        utils.getPath(currDir, "/$#".format($inputFile))
    ])

    # Once compiled will get the generated files from nimcache directory.
    # We care about the source C files that node-gyp will
    # have to know about. We can get them from the json file's
    # compile property that has a list of the C files.
    display("Sucessfully compiled your Nim project to C", indent=2)
    display("Now, invoke node-gyp...", indent=2, br="after")

    var gyp = %* {
        "targets": [getNodeGypConfig()]
    }

    var
        jsonConfigPath = cachePathDirectory & "/" & entryFile.replace(".nim", ".json")
        jsonConfigContents = parseJson(readFile(jsonConfigPath))
        jarr = newJArray()
    
    for elem in items(jsonConfigContents["compile"].elems):
        jarr.add(newJString(elem[0].getStr().replace(addonPathDirectory&"/", "")))
    gyp["targets"][0]["sources"] = %* jarr

    writeFile(addonPathDirectory & "/binding.gyp", pretty(gyp, 4))

    # Invoke Node GYP for bundling the node addon
    display("✨ Node GYP output", indent=2, br="both")
    echo cmd("node-gyp", [
        "rebuild", "--directory="&addonPathDirectory, "--loglevel", "silent"
    ])

    let
        binaryNodePath = utils.getPath(currDir, "/denim_build/build/Release/main.node")
        binDirectory = currDir & "/bin"
        binaryTargetPath = binDirectory & "/" & entryFile.replace(".nim", ".node")

    if os.fileExists(binaryNodePath) == false:
        display("👉 Could not find the compiled addon file. Try build again", indent=2)
    else:
        discard os.existsOrCreateDir(binDirectory)              # ensure bin directory exists
        os.moveFile(binaryNodePath, binaryTargetPath)           # move .node addon
        display("👌 Denim sucessfully compiled your Node addon", indent=2, br="both")

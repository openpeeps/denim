import os, json, tables
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
        "cflags": release == true ? "['-w', '-O3', '-fno-strict-aliasing']" ! "['-w']",
        "linkflags": "['-ldl']",
        "sources": [],
    }

    return config

proc runCompileCmd*(args: Table[system.string, system.any]): string =
    # Compile project to source code by using Nim compiler
    # https://nim-lang.org/docs/nimc.html
    let current_dir = os.getCurrentDir()
    let cachePathDirectory = utils.getPath(current_dir, "/example")
    # checking if cache directory contains any files from previous compilation
    if isEmptyDir(cachePathDirectory) == false:
        echo printInfo("Directory is not empty: " & cachePathDirectory)
        let confirmedDeletion = cli.confirm("Do you want to remove previously compiled files?")
        if confirmedDeletion == false:
            return

    # for project in @(args["<project>"]): 
        # echo "Creating a new Denim project for $#" % project

    let gyp_config = %* {
        "targets": getNodeGypConfig()
    }

    # echo $gyp_config

    let isRelease = false
    let build_flag = isRelease ? "-d:release" ! "--embedsrc"
    let getMainFilePath = current_dir

    # Runs the nim compiler on the entry file and creates the equivalent C files in
    # nimcache to be used by node-gyp for building the node addon
    cmd("nim", [
        "c",
        "--nimcache:"&cachePathDirectory,
        build_flag,
        "--compileOnly",
        "--noMain",
        utils.getPath(current_dir, "/src/denim/example.nim")
    ])

    # Once compiled will get the generated files from nimcache directory
    # and the created metadata JSON related to generated C files.

    # We care about the source C files that node-gyp will
    # have to know about. We can get them from the json file's
    # compile property that has a list of the C files.
    # let jsonGen = "test_path_to.json"
    # echo gyp_config.targets.sources

import os, json, tables, strutils
import ../utils
import macros
from clymene/util import cmd

macro `?`(a: bool, body: untyped): untyped =
    # Create a macro for a short hand conditional
    # value == expected ? "do something" ! "not yet"
    # https://nim-lang.org/docs/sugar.html
    let x = body[1]
    let y = body[2]
    result = quote:
        if `a`: `x` else: `y`

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

#https://nim-lang.org/docs/manual.html#pragmas
# proc printf(formatstr: cstring) {.importc: "printf", varargs, header: "<stdio.h>".}
# let t = printf("This works %s %s", "as expected")

# https://livebook.manning.com/concept/nim/await
proc runCompileCmd*(args: Table[system.string, system.any]): string =
    # Compile project to source code by using Nim compiler
    # https://nim-lang.org/docs/nimc.html
    let current_dir = os.getCurrentDir()
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
        "--nimcache:"&utils.getPath(current_dir, "/example"),
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

# Node-API (N-API) bindings for Nim.
#
# Originally written by Andrew Breidenbach, later modified by Andrei Rosca
# and now fully implemented in Nim and maintained by OpenPeeps.
# 
#     https://github.com/AjBreidenbach
#     https://github.com/andi23rosca
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/denim

import std/[os, osproc, json, strutils]
import kapsis/runtime
import kapsis/interactive/prompts
import ../utils


proc detectNimToolchainPath(): string =
  # Detect the Nim toolchain path by parsing the output of `nim dump`
  let d = execCmdEx("nim dump")
  if d.exitCode != 0: return

  # parse from bottom; nim prints final lib paths near the end
  let lines = d.output.splitLines()
  for i in countdown(lines.high, 0):
    var p = lines[i].strip()
    if p.len == 0:
      continue

    # normalize quoted lines
    p = p.strip(chars = {'"', '\''})

    # candidate A: line is ".../lib"
    if dirExists(p) and p.endsWith("/lib") or p.endsWith("\\lib"):
      let root = p.parentDir
      if fileExists(root / "lib" / "nimbase.h"):
        return root

    if dirExists(p):
      let idx1 = p.rfind("/lib/")
      let idx2 = p.rfind("\\lib\\")
      let idx = max(idx1, idx2)
      if idx >= 0:
        let root = p[0 ..< idx].strip()
        if root.len > 0 and fileExists(root / "lib" / "nimbase.h"):
          return root

proc getNodeGypConfig(getNimPath: string, release: bool = false): JsonNode = 
  return %* {
    "target_name": "main",
    "include_dirs": [
      getNimPath
    ],
    "cflags": if release: %*["-w", "-O3", "-fno-strict-aliasing"] else: %*["-w"],
    "linkflags": ["-ldl"]
  }

# https://stackoverflow.com/questions/52605527/cmake-or-g-include-dll-libraries
const cMakeListsContent = """
cmake_minimum_required(VERSION 3.15)
cmake_policy(SET CMP0091 NEW)
cmake_policy(SET CMP0042 NEW)

project (DENIM_PKG_NAME)

add_definitions(-DNAPI_VERSION=4)

include_directories(${CMAKE_JS_INC})

file(GLOB SOURCE_FILES DENIM_GLOB_SOURCES)

add_library(DENIM_PKG_NAME SHARED ${SOURCE_FILES} ${CMAKE_JS_SRC})
set_target_properties(DENIM_PKG_NAME PROPERTIES LINKER_LANGUAGE CXX PREFIX "" SUFFIX ".node")

DENIM_PKG_LINK_LIBS

if(MSVC AND CMAKE_JS_NODELIB_DEF AND CMAKE_JS_NODELIB_TARGET)
  # Generate node.lib
  execute_process(COMMAND ${CMAKE_AR} /def:${CMAKE_JS_NODELIB_DEF} /out:${CMAKE_JS_NODELIB_TARGET} ${CMAKE_STATIC_LINKER_FLAGS})
endif()
"""

proc buildCommand*(v: Values) =
  ## Compile project to source code by using Nim compiler
  # https://nim-lang.org/docs/nimc.html
  let inputFile = v.get("nim").getPath().path
  var
    currDir = getCurrentDir()
    addonPathDirectory = utils.getPath(currDir, "" / "denim_build")
    cachePathDirectory = addonPathDirectory / "nimcache"
    path = splitPath(inputFile)
    entryFile = path.tail
  if not entryFile.endsWith(".nim") or fileExists(inputFile) == false:
    display("Missing '.nim' file", indent=2)
    QuitFailure.quit

  if not isEmptyDir(addonPathDirectory):
    if not v.has("-y"):
      displayInfo("Directory is not empty: " & os.splitPath(addonPathDirectory).tail)
      if promptConfirm("Do you want to remove current contents? (y/N)"):
        os.removeDir(addonPathDirectory)
      else:
        display("Canceled", indent=2, br="after")
        QuitFailure.quit
    else:
      os.removeDir(addonPathDirectory)
  displayInfo("Running Nim Compiler")
    
  var args = @[
    "--nimcache:$1",
    "--define:napibuild",
    "--compileOnly",
    "--noMain"
  ]
  if v.has("-r"):
    add args, "-d:release"
    add args, "--opt:speed"
  else:
    add args, "--embedsrc"

  let nimc = "nim c " & args.join(" ") & " $2"
  let nimCmd = execCmdEx(nimc % [
    cachePathDirectory,
    utils.getPath(currDir, "" / "$#".format(inputFile))
  ])
  if nimCmd.exitCode != 0:
    display(nimCmd.output)
    QuitFailure.quit
  elif v.has("--verbose"):
    display(nimCmd.output)
  let getNimPath = detectNimToolchainPath()
  if getNimPath.len == 0:
    displayError("Can't find Nim toolchain path (from `nim`/`nim dump`)")
    QuitFailure.quit
    QuitFailure.quit
  discard execProcess("ln", args = [
    "-s",
    getNimPath / "lib" / "nimbase.h",
    cachePathDirectory
  ], options={poStdErrToStdOut, poUsePath})
  
  if v.has("--cmake"):
    displayInfo("Building with CMake.js")

    # cmake - add target libs, if any
    var denimLinkLibs: seq[string]
    if v.has("--libs"):
      for x in v.get("--libs").getStr.split(","):
        denimLinkLibs.add(x)

    let pkgName = entryFile.splitFile.name
    var globSources: seq[string]
    for pattern in ["*.c", "*.h"]:
      globSources.add(os.joinPath(currDir, "denim_build" / "nimcache", pattern))
    writeFile(currDir / "CMakeLists.txt",
      cMakeListsContent.multiReplace(
        ("DENIM_GLOB_SOURCES", globSources.join(" ")),
        ("DENIM_PKG_NAME", pkgName),
        ("DENIM_PKG_LINK_LIBS",
          if denimLinkLibs.len > 0:
            "target_link_libraries(" & pkgName & " " & denimLinkLibs.join(" ") & ")"
          else: ""
        )
      )
    )
    # Build the native addon using CMake.js
    let cmakeCmd = execCmdEx("cmake-js compile --runtime node --out " & "denim_build" / "build")
    if cmakeCmd.exitCode != 0:
      display(cmakeCmd.output)
      QuitFailure.quit
    elif v.has("--verbose"):
      display(cmakeCmd.output)
  else:
    # When using `node-gyp`, we need to generate a `binding.gyp` file with
    # the correct configuration
    displayInfo("Building with node-gyp")
    var gyp = %* {"targets": [getNodeGypConfig(getNimPath, v.has("-r"))]}
    let jsonConfigPath = cachePathDirectory / entryFile.replace(".nim", ".json")
    
    var jarr = newJArray()
    let jsonConfigContents = parseJson(readFile(jsonConfigPath))
    
    for elem in items(jsonConfigContents["compile"].elems):
      jarr.add(newJString(elem[0].getStr().replace(addonPathDirectory / "", "")))
    
    # Set the source files in the `binding.gyp` configuration
    gyp["targets"][0]["sources"] = %* jarr
    
    # Write `binding.gyp` file for node-gyp
    writeFile(addonPathDirectory / "binding.gyp", pretty(gyp, 2))
    
    # Build the native addon using node-gyp
    let gypCmd = execCmdEx("node-gyp rebuild --directory=" & addonPathDirectory)
    
    # Check if the build was successful
    if gypCmd.exitCode != 0:
      display(gypCmd.output)
      QuitFailure.quit
    elif v.has("--verbose"):
      display(gypCmd.output)
  let
    defaultBinName =
      if v.has("--cmake"):
        entryFile.splitFile.name
      else: "main"
    binaryNodePath = utils.getPath(currDir, "" / "denim_build" / "build" / "Release" / defaultBinName & ".node")
    binDirectory = currDir / "bin"
    binName = entryFile.replace(".nim", ".node")
    binaryTargetPath = binDirectory / binName

  if fileExists(binaryNodePath) == false:
    displayError("Oups! $1 not found. Try build again" % [binName])
    QuitFailure.quit
  else:
    discard existsOrCreateDir(binDirectory)              # ensure bin directory exists
    moveFile(binaryNodePath, binaryTargetPath)           # move .node addon
    displaySuccess("Done! Check your `bin` directory")
    displayInfo(binDirectory)

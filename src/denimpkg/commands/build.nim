import std/[os, osproc, json, strutils]
import kapsis/[cli, runtime]
import ../utils

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

file(GLOB SOURCE_FILES "./denim_build/nimcache/*.c" "./denim_build/nimcache/*.h")

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
      if promptConfirm("👉 Do you want to remove current contents? (y/N)"):
        os.removeDir(addonPathDirectory)
      else:
        display("Canceled", indent=2, br="after")
        QuitFailure.quit
    else:
      os.removeDir(addonPathDirectory)
  displayInfo("🔥 Running Nim Compiler")
    
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
  var getNimPath = execCmdEx("choosenim show path")
  if getNimPath.exitCode != 0:
    displayError("Can't find Nim path")
    QuitFailure.quit
  discard execProcess("ln", args = [
    "-s",
    strip(getNimPath.output) / "lib" / "nimbase.h",
    cachePathDirectory
  ], options={poStdErrToStdOut, poUsePath})
  
  if v.has("--cmake"):
    displayInfo("✨ Building with CMake.js")

    # cmake - add target libs, if any
    var denimLinkLibs: seq[string]
    if v.has("--libs"):
      for x in v.get("--libs").getStr.split(","):
        denimLinkLibs.add(x)

    let pkgName = entryFile.splitFile.name
    writeFile(currDir / "CMakeLists.txt",
      cMakeListsContent.multiReplace(
        ("DENIM_PKG_NAME", pkgName),
        ("DENIM_PKG_LINK_LIBS",
          if denimLinkLibs.len > 0:
            "target_link_libraries(" & pkgName & " " & denimLinkLibs.join(" ") & ")"
          else: ""
        )
      )
    )
    let cmakeCmd = execCmdEx("cmake-js compile --runtime node --out " & "denim_build" / "build")
    if cmakeCmd.exitCode != 0:
      display(cmakeCmd.output)
      QuitFailure.quit
    elif v.has("--verbose"):
      display(cmakeCmd.output)
  else:
    displayInfo("✨ Building with node-gyp")
    var
      gyp = %* {"targets": [getNodeGypConfig(getNimPath.output.strip, v.has("-r"))]}
      jsonConfigPath = cachePathDirectory / entryFile.replace(".nim", ".json")
    var
      jarr = newJArray()
      jsonConfigContents = parseJson(readFile(jsonConfigPath))
    for elem in items(jsonConfigContents["compile"].elems):
      jarr.add(newJString(elem[0].getStr().replace(addonPathDirectory / "", "")))
    gyp["targets"][0]["sources"] = %* jarr
    writeFile(addonPathDirectory / "binding.gyp", pretty(gyp, 2))
    let gypCmd = execCmdEx("node-gyp rebuild --directory=" & addonPathDirectory)
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
    displayError("👉 Oups! $1 not found. Try build again" % [binName])
    QuitFailure.quit
  else:
    discard existsOrCreateDir(binDirectory)              # ensure bin directory exists
    moveFile(binaryNodePath, binaryTargetPath)           # move .node addon
    displaySuccess("👌 Done! Check your `bin` directory")
    displayInfo(binDirectory)

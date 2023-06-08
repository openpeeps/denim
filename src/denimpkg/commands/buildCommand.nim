import std/[os, osproc, json, strutils]
import ../utils
import kapsis/[cli, runtime]

proc getNodeGypConfig(getNimPath: string, release: bool = false): JsonNode = 
  return %* {
    "target_name": "main",
    "include_dirs": [
      getNimPath
    ],
    "cflags": if release: %*["-w", "-O3", "-fno-strict-aliasing"] else: %*["-w"],
    "linkflags": ["-ldl"]
  }

proc runCommand*(v: Values) =
  ## Compile project to source code by using Nim compiler
  # https://nim-lang.org/docs/nimc.html
  let inputFile = v.get("entry")
  let links = v.get("links")
  echo links
  var
    currDir = getCurrentDir()
    addonPathDirectory = utils.getPath(currDir, "" / "denim_build")
    cachePathDirectory = addonPathDirectory / "nimcache"
    path = splitPath(inputFile)
    entryFile = path.tail
  if not entryFile.endsWith(".nim") or fileExists(inputFile) == false:
    display("Entry file should be the main '.nim' file of your project", indent=2)
    QuitFailure.quit

  # checking if cache directory contains any files from previous compilation
  if isEmptyDir(addonPathDirectory) == false:
    display("Directory is not empty: " & os.splitPath(addonPathDirectory).tail, indent=2, br="after")
    if promptConfirm("👉 Are you sure you want to remove contents?"):
      os.removeDir(addonPathDirectory)
    else:
      display("Canceled", indent=2, br="after")
      QuitFailure.quit
  display("🔥 Nim Compiler", indent=2, br="both")
  
  # TODO expose nim flags
  var args = @[
    "--nimcache:$1",
    "-d:napibuild",
    "--compileOnly",
    "--noMain",
    "--gc:arc",
    "--deepcopy:on",
    "--threads:on"
  ]

  if v.flag("release"):
    add args, "-d:release"
    add args, "--opt:speed"
  else:
    add args, "--embedsrc"

  let nimCompileCmd = "nim c " & args.join(" ") & " $2"
  let status = execCmdEx(nimCompileCmd % [
    cachePathDirectory,
    utils.getPath(currDir, "" / "$#".format(inputFile))
  ])
  if status.exitCode != 0:
    display(status.output)
    QuitFailure.quit

  var getNimPath = execCmdEx("choosenim show path")
  if getNimPath.exitCode != 0:
    display("Can't find Nim path")
    QuitFailure.quit
  discard execProcess("ln", args = [
    "-s",
    strip(getNimPath.output) / "lib" / "nimbase.h",
    cachePathDirectory
  ], options={poStdErrToStdOut, poUsePath})
  
  display("Invoke node-gyp...", indent=2, br="after")
  var
    gyp = %* {"targets": [getNodeGypConfig(getNimPath.output.strip, v.flag("release"))]}
    jsonConfigPath = cachePathDirectory / entryFile.replace(".nim", ".json")
  var
    jsonConfigContents = parseJson(readFile(jsonConfigPath))
    jarr = newJArray()
  for elem in items(jsonConfigContents["compile"].elems):
    jarr.add(newJString(elem[0].getStr().replace(addonPathDirectory / "", "")))
  gyp["targets"][0]["sources"] = %* jarr

  writeFile(addonPathDirectory / "binding.gyp", pretty(gyp, 2))

  # Invoke Node GYP for bundling the node addon
  display("✨ Node GYP output", indent=2, br="both")
  # todo expose https://github.com/nodejs/node-gyp#command-options
  echo execProcess("node-gyp", args = ["rebuild", "--release", "--directory="&addonPathDirectory], options={poStdErrToStdOut, poUsePath})
  let
    binaryNodePath = utils.getPath(currDir, "" / "denim_build" / "build" / "Release" / "main.node")
    binDirectory = currDir / "bin"
    binName = entryFile.replace(".nim", ".node")
    binaryTargetPath = binDirectory / binName

  if fileExists(binaryNodePath) == false:
    display("👉 Oups! $1 not found. Try build again" % [binName], indent=2)
  else:
    discard existsOrCreateDir(binDirectory)              # ensure bin directory exists
    moveFile(binaryNodePath, binaryTargetPath)           # move .node addon
    display("👌 Sucessfully compiled your Node addon", indent=2, br="both")
    QuitSuccess.quit
import std/[os, osproc, json, strutils]
import ../utils
# from klymene/util import cmd, cmdExec, isEmptyDir
import klymene/[cli, runtime]

proc getNodeGypConfig(release: bool = false): JsonNode = 
  return %* {
    "target_name": "main",
    "include_dirs": [
      utils.getNimPath()
    ],
    "cflags": if release: %*["-w", "-O3", "-fno-strict-aliasing"] else: %*["-w"],
    "linkflags": ["-ldl"]
  }

proc findNimStdLib(): string =
  try:
    let nimexe = os.findExe("nim")
    echo nimexe
    if nimexe.len == 0: return ""
    result = nimexe.splitPath()[0] /../ "lib"
    if not fileExists(result / "system.nim"):
      when defined(unix):
        result = nimexe.expandSymlink.splitPath()[0] /../ "lib"
        if not fileExists(result / "system.nim"): return ""
  except OSError, ValueError:
    return ""

proc runCommand*(v: Values) =
  ## Compile project to source code by using Nim compiler
  # https://nim-lang.org/docs/nimc.html
  let inputFile = v.get("entry")
  echo inputFile
  var
    currDir = getCurrentDir()
    addonPathDirectory = utils.getPath(currDir, "/denim_build")
    cachePathDirectory = addonPathDirectory & "/nimcache"
    path = splitPath(inputFile)
    entryFile = path.tail
  if not entryFile.endsWith(".nim"):
    display("Entry file should be the main '.nim' file of your project", indent=2)
    quit()
  display("Start compiling $# ...".format(entryFile), indent=2, br="both")

  # checking if cache directory contains any files from previous compilation
  if isEmptyDir(addonPathDirectory) == false:
    display("Directory is not empty: " & os.splitPath(addonPathDirectory).tail, indent=2, br="after")
    if promptConfirm("👉 Are you sure you want to remove contents?"):
      os.removeDir(addonPathDirectory)
    else:
      display("Canceled", indent=2, br="after")
      QuitFailure.quit
  var isRelease = true
  # var build_flag = if isRelease: "-d:release" else: "--embedsrc"
  display("🔥 Nim Compiler output", indent=2, br="both")
  echo utils.getPath(currDir, "/$#".format(inputFile))
  let nimCompileCmd = "nim c --nimcache:$1 --opt:size -d:release --compileOnly --noMain --warnings:off $2" % [
    cachePathDirectory, utils.getPath(currDir, "/$#".format(inputFile))
  ]
  let status = execCmdEx(nimCompileCmd)
  if status.exitCode != 0:
    display(status.output)
    QuitFailure.quit

  # Once compiled will get the generated files from nimcache directory.
  # We care about the source C files that node-gyp will
  # have to know about. We can get them from the json file's
  # compile property that has a list of the C files.
  display("Sucessfully compiled your Nim project to C", indent=2)
  # TODO find if nim was installed via choosenim,
  # and create a symlink of `nimbase` header to `cachePathDirectory`
  # to satisfy node-gyp requirements
  discard execProcess("ln", args = [
    "-s",
    "/Users/georgelemon/.choosenim/toolchains/nim-1.6.10/lib/nimbase.h",
    cachePathDirectory
  ], options={poStdErrToStdOut, poUsePath})
  display("Now, invoke node-gyp...", indent=2, br="after")
  var
    gyp = %* {"targets": [getNodeGypConfig()]}
    jsonConfigPath = cachePathDirectory & "/" & entryFile.replace(".nim", ".json")
  var
    jsonConfigContents = parseJson(readFile(jsonConfigPath))
    jarr = newJArray()
  for elem in items(jsonConfigContents["compile"].elems):
    jarr.add(newJString(elem[0].getStr().replace(addonPathDirectory&"/", "")))
  gyp["targets"][0]["sources"] = %* jarr

  writeFile(addonPathDirectory & "/binding.gyp", pretty(gyp, 2))

  # Invoke Node GYP for bundling the node addon
  display("✨ Node GYP output", indent=2, br="both")
  echo findNimStdLib()
  echo execProcess("node-gyp", args = ["rebuild", "--directory="&addonPathDirectory], options={poStdErrToStdOut, poUsePath})
  let
    binaryNodePath = utils.getPath(currDir, "/denim_build/build/Release/main.node")
    binDirectory = currDir & "/bin"
    binaryTargetPath = binDirectory & "/" & entryFile.replace(".nim", ".node")

  if fileExists(binaryNodePath) == false:
    display("👉 Could not find the compiled addon file. Try build again", indent=2)
  else:
    discard existsOrCreateDir(binDirectory)              # ensure bin directory exists
    moveFile(binaryNodePath, binaryTargetPath)           # move .node addon
    display("👌 Denim sucessfully compiled your Node addon", indent=2, br="both")
    QuitSuccess.quit
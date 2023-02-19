import std/[os, osproc, json, strutils]
import ../utils
import klymene/[cli, runtime]

proc getNodeGypConfig(getNimPath: string, release: bool = false): JsonNode = 
  echo getNimPath
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
  var
    currDir = getCurrentDir()
    addonPathDirectory = utils.getPath(currDir, "/denim_build")
    cachePathDirectory = addonPathDirectory & "/nimcache"
    path = splitPath(inputFile)
    entryFile = path.tail
  if not entryFile.endsWith(".nim"):
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
  # echo utils.getPath(currDir, "/$#".format(inputFile))
  var args = @[
    "--nimcache:$1",
    "--opt:size",
    "-d:napibuild",
    "-d:release"
    "--compileOnly",
    "--noMain",
    "--warnings:off",
    "--gc:arc",
    "--deepcopy:on",
    # "--threads:on",
  ]

  # if v.flag("release"):
  #   add args, "-d:release"
  # else:
  #   add args, "--embedsrc"
  if v.flag("threads"):
    add args, "--threads:on"

  let nimCompileCmd = "nim c " & args.join(" ") & " $2"
  let status = execCmdEx(nimCompileCmd % [
    cachePathDirectory,
    utils.getPath(currDir, "/$#".format(inputFile))
  ])
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
  var getNimPath = execCmdEx("choosenim show path")
  if getNimPath.exitCode != 0:
    display("The current Nim installation path could not be found")
    QuitFailure.quit
  discard execProcess("ln", args = [
    "-s",
    strip(getNimPath.output) & "/lib/nimbase.h",
    cachePathDirectory
  ], options={poStdErrToStdOut, poUsePath})
  display("Now, invoke node-gyp...", indent=2, br="after")
  var
    gyp = %* {"targets": [getNodeGypConfig(getNimPath.output.strip)]}
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
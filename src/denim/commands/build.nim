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

import std/[os, osproc, json, strutils, sequtils]
import kapsis/runtime
import kapsis/interactive/prompts
import ../utils

# ---------------------------------------------------------------------------
# Helpers for vendored C support ({.compile.} + passC/passL)
# ---------------------------------------------------------------------------

proc stripSurroundingQuotes*(s: string): string =
  ## Remove one pair of surrounding single/double quotes, if present.
  if s.len >= 2:
    if (s[0] == '"' and s[^1] == '"') or (s[0] == '\'' and s[^1] == '\''):
      return s[1 .. ^2]
  return s

proc parseStringList*(s: string): seq[string] =
  ## Accept either a comma-separated string ("a,b,c") or a stringified
  ## JSON array ('["a","b","c"]'). Used by --linkFlags, --includeDirs, etc.
  ## so users can pass a plain string or an array of strings.
  result = @[]
  let t = s.strip()
  if t.len == 0:
    return
  if t.startsWith("["):
    try:
      let j = parseJson(t)
      if j.kind == JArray:
        for e in j.elems:
          case e.kind
          of JString:
            let v = e.getStr().strip()
            if v.len > 0: result.add(v)
          else:
            let v = stripSurroundingQuotes(($e).strip())
            if v.len > 0: result.add(v)
        return
    except JsonParsingError:
      discard
    # fall through to comma split on parse failure
  for part in t.split(","):
    var p = stripSurroundingQuotes(part.strip())
    if p.len > 0:
      result.add(p)

proc getStringList*(v: Values, name: string): seq[string] =
  ## Read an optional ?string CLI flag as a string list.
  if v.has(name):
    try:
      return parseStringList(v.get(name).getStr)
    except CatchableError:
      return @[]
  return @[]

proc splitShellCmd*(cmd: string): seq[string] =
  ## Split a compiler command line the way a POSIX shell would, respecting
  ## single/double quotes and backslash escapes. Quote characters are
  ## consumed (not kept), matching shell behavior.
  result = @[]
  var cur = ""
  var inSingle = false
  var inDouble = false
  var escaped = false
  var hasToken = false
  for ch in cmd:
    if escaped:
      cur.add(ch)
      escaped = false
      hasToken = true
      continue
    if ch == '\\' and not inSingle:
      escaped = true
      hasToken = true
      continue
    if ch == '\'' and not inDouble:
      inSingle = not inSingle
      hasToken = true
      continue
    if ch == '"' and not inSingle:
      inDouble = not inDouble
      hasToken = true
      continue
    if (ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r') and not inSingle and not inDouble:
      if hasToken:
        result.add(cur)
        cur = ""
        hasToken = false
      continue
    cur.add(ch)
    hasToken = true
  if hasToken:
    result.add(cur)

proc dedupPreserveOrder*(items: seq[string]): seq[string] =
  result = @[]
  for x in items:
    if x notin result:
      result.add(x)

proc cmakeQuote*(s: string): string =
  ## Quote a single CMake argument if it contains spaces or special chars.
  if s.len == 0:
    return "\"\""
  if not s.contains({' ', '\t', '"', ';', '('}):
    return s
  var e = s.replace("\\", "\\\\").replace("\"", "\\\"")
  return "\"" & e & "\""

proc cmakeEscapeDefine*(def: string): string =
  ## Escape a -D flag for use inside add_definitions().
  ## The flag keeps its -D prefix; inner quotes/backslashes are escaped
  ## so CMake forwards e.g. -DCONFIG_VERSION="2024-01-13" intact.
  var e = def.replace("\\", "\\\\").replace("\"", "\\\"")
  if e.contains({' ', '\t', ';'}):
    e = "\"" & e & "\""
  return e

type NimBuildInfo* = object
  sources*: seq[string]
  includeDirs*: seq[string]
  defines*: seq[string]      # full "-D..." tokens
  compileOpts*: seq[string]  # other passC-ish options
  linkOpts*: seq[string]     # raw linker tokens from linkcmd

proc extractBuildInfo*(cfg: JsonNode): NimBuildInfo =
  ## Pull sources + flags out of the nimcache/<entry>.json written by
  ## `nim c --compileOnly`. Compile entries are [src, cmd] pairs; link
  ## flags come from the `linkcmd` string.
  result = NimBuildInfo(
    sources: @[], includeDirs: @[],
    defines: @[], compileOpts: @[], linkOpts: @[]
  )
  if cfg.kind != JObject:
    return
  if cfg.hasKey("compile") and cfg["compile"].kind == JArray:
    for elem in cfg["compile"].elems:
      if elem.kind != JArray or elem.elems.len < 2:
        continue
      let src = elem[0].getStr()
      if src.len > 0 and src notin result.sources:
        result.sources.add(src)
      let tokens = splitShellCmd(elem[1].getStr())
      var i = 0
      # skip compiler binary (token 0)
      if tokens.len > 0:
        i = 1
      var pendingInclude = false
      var pendingDefine = false
      while i < tokens.len:
        let tok = tokens[i]
        if pendingInclude:
          let d = tok.stripSurroundingQuotes()
          if d.len > 0 and d notin result.includeDirs:
            result.includeDirs.add(d)
          pendingInclude = false
          inc i
          continue
        if pendingDefine:
          let d = "-D" & tok
          if d notin result.defines:
            result.defines.add(d)
          pendingDefine = false
          inc i
          continue
        if tok == "-c" or tok == "-o":
          # skip "-o <output>" entirely
          if tok == "-o":
            inc i # skip output file too
          inc i
          continue
        elif tok == "-I":
          pendingInclude = true
        elif tok == "-D":
          pendingDefine = true
        elif tok.startsWith("-I"):
          let d = tok[2 .. ^1].stripSurroundingQuotes()
          if d.len > 0 and d notin result.includeDirs:
            result.includeDirs.add(d)
        elif tok.startsWith("-D"):
          if tok notin result.defines:
            result.defines.add(tok)
        elif tok.startsWith("-U"):
          if tok notin result.defines:
            result.defines.add(tok)
        elif tok.endsWith(".c") or tok.endsWith(".o") or
             tok.endsWith(".obj") or tok.endsWith(".cpp"):
          # input/output file, not a flag
          discard
        elif tok.startsWith("-"):
          # other compiler flags (-w, -O*, -f*, -W*, -std=*, -pthread, ...)
          # skip Nim-only object-file markers already handled above
          if tok notin result.compileOpts and
             tok notin ["-c", "-o"]:
            result.compileOpts.add(tok)
        # bare paths / compiler binary leftovers are ignored
        inc i
  if cfg.hasKey("linkcmd") and cfg["linkcmd"].kind == JString:
    for tok in splitShellCmd(cfg["linkcmd"].getStr()):
      if tok.startsWith("-"):
        if tok in ["-o", "-c"]:
          continue
        if tok.endsWith(".o") or tok.endsWith(".obj"):
          continue
        if tok notin result.linkOpts:
          result.linkOpts.add(tok)
      # object files / output binary are skipped

proc readNimBuildInfo*(jsonPath: string): NimBuildInfo =
  ## Read nimcache JSON, returning empty info (not a crash) when missing.
  result = NimBuildInfo(
    sources: @[], includeDirs: @[],
    defines: @[], compileOpts: @[], linkOpts: @[]
  )
  if not fileExists(jsonPath):
    return
  try:
    return extractBuildInfo(parseJson(readFile(jsonPath)))
  except CatchableError:
    return result

proc splitDefineForGyp*(def: string): string =
  ## Strip the leading -D/-U for node-gyp `defines` entries.
  if def.startsWith("-D"):
    return def[2 .. ^1]
  if def.startsWith("-U"):
    return def[2 .. ^1]
  return def

proc gypRelPath*(src, baseDir: string): string =
  ## Make a source path relative to the binding.gyp directory so node-gyp
  ## generates valid object paths. Nimcache files become `nimcache/...`,
  ## outside files (e.g. {.compile.} vendored C) become `../vendor/...`
  ## instead of absolute paths (which break gyp's obj path computation).
  let prefix = baseDir & "/"
  if src.startsWith(prefix):
    return src[prefix.len .. ^1]
  try:
    return os.relativePath(src, baseDir)
  except CatchableError:
    return src


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

add_definitions(-DNAPI_VERSION=4 DENIM_DEFINES)

include_directories(${CMAKE_JS_INC} DENIM_INCLUDE_DIRS)

set(SOURCE_FILES DENIM_EXPLICIT_SOURCES)

add_library(DENIM_PKG_NAME SHARED ${SOURCE_FILES} ${CMAKE_JS_SRC})
set_target_properties(DENIM_PKG_NAME PROPERTIES LINKER_LANGUAGE CXX PREFIX "" SUFFIX ".node")
DENIM_COMPILE_OPTS_LINE
DENIM_PKG_LINK_LIBS
DENIM_PKG_LINK_OPTS_LINE
if(APPLE)
  target_link_libraries(DENIM_PKG_NAME "-framework Security")
endif()

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

    let jsonConfigPath = cachePathDirectory / entryFile.changeFileExt("nim", "json")
    let autoInfo = readNimBuildInfo(jsonConfigPath)

    # Manual overrides (all accept "a,b" or '["a","b"]').
    let manualIncludeDirs = v.getStringList("--includeDirs")
    let manualIncludeFilesRaw = v.getStringList("--includeFiles")
    let manualDefinesRaw = v.getStringList("--defines")
    var manualCflags: seq[string] = @[]
    for entry in v.getStringList("--cflags"):
      for tok in splitShellCmd(entry):
        if tok.len > 0:
          manualCflags.add(tok)
    var manualLinkFlags: seq[string] = @[]
    for entry in v.getStringList("--linkFlags"):
      for tok in splitShellCmd(entry):
        if tok.len > 0:
          manualLinkFlags.add(tok)

    # Resolve manual include files relative to the project dir.
    var manualIncludeFiles: seq[string] = @[]
    for f in manualIncludeFilesRaw:
      if f.len == 0: continue
      if os.isAbsolute(f): manualIncludeFiles.add(f)
      else: manualIncludeFiles.add(currDir / f)

    # Sources: explicit list from Nim JSON (covers {.compile.} files living
    # outside nimcache) + manual files. Fall back to the old GLOB when the
    # JSON is unavailable.
    var explicitSources = dedupPreserveOrder(autoInfo.sources & manualIncludeFiles)
    if explicitSources.len == 0:
      for pattern in ["*.c"]:
        explicitSources.add(os.joinPath(currDir, "denim_build" / "nimcache", pattern))
    let pkgName = entryFile.splitFile.name
    var quotedSources: seq[string] = @[]
    for s in explicitSources:
      if s.contains("*"):
        quotedSources.add(s) # legacy glob fallback, kept unquoted
      else:
        quotedSources.add(cmakeQuote(s))

    # Include dirs: nimcache (nimbase.h symlink lives here) + auto -I + manual.
    var allIncludeDirs = dedupPreserveOrder(
      @[cachePathDirectory] & autoInfo.includeDirs & manualIncludeDirs)
    var quotedIncludes: seq[string] = @[]
    for d in allIncludeDirs:
      quotedIncludes.add(cmakeQuote(d))

    # Defines: auto -D/-U + manual --defines (bare NAME=VAL gets -D prefix).
    var allDefines = autoInfo.defines
    for d in manualDefinesRaw:
      if d.startsWith("-D") or d.startsWith("-U"):
        if d notin allDefines: allDefines.add(d)
      else:
        let full = "-D" & d
        if full notin allDefines: allDefines.add(full)
    allDefines = dedupPreserveOrder(allDefines)
    var escapedDefines: seq[string] = @[]
    for d in allDefines:
      escapedDefines.add(cmakeEscapeDefine(d))

    # Other compile options.
    let allCompileOpts = dedupPreserveOrder(autoInfo.compileOpts & manualCflags)
    var quotedCompileOpts: seq[string] = @[]
    for o in allCompileOpts:
      quotedCompileOpts.add(cmakeQuote(o))
    let compileOptsLine =
      if quotedCompileOpts.len > 0:
        "target_compile_options(" & pkgName & " PRIVATE " & quotedCompileOpts.join(" ") & ")"
      else: ""

    # Link: auto link opts ({.passL.}) + manual --linkFlags.
    var linkLibs = dedupPreserveOrder(autoInfo.linkOpts & manualLinkFlags)
    let linkLibsLine =
      if linkLibs.len > 0:
        "target_link_libraries(" & pkgName & " " & linkLibs.join(" ") & ")"
      else: ""
    writeFile(currDir / "CMakeLists.txt",
      cMakeListsContent.multiReplace(
        ("DENIM_EXPLICIT_SOURCES", quotedSources.join(" ")),
        ("DENIM_INCLUDE_DIRS", quotedIncludes.join(" ")),
        ("DENIM_DEFINES", escapedDefines.join(" ")),
        ("DENIM_COMPILE_OPTS_LINE", compileOptsLine),
        ("DENIM_PKG_NAME", pkgName),
        ("DENIM_PKG_LINK_LIBS", linkLibsLine),
        ("DENIM_PKG_LINK_OPTS_LINE", "")
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
    let autoInfo = readNimBuildInfo(jsonConfigPath)

    let manualIncludeDirs = v.getStringList("--includeDirs")
    let manualIncludeFilesRaw = v.getStringList("--includeFiles")
    let manualDefinesRaw = v.getStringList("--defines")
    var manualCflags: seq[string] = @[]
    for entry in v.getStringList("--cflags"):
      for tok in splitShellCmd(entry):
        if tok.len > 0:
          manualCflags.add(tok)
    var manualLinkFlags: seq[string] = @[]
    for entry in v.getStringList("--linkFlags"):
      for tok in splitShellCmd(entry):
        if tok.len > 0:
          manualLinkFlags.add(tok)

    var manualIncludeFiles: seq[string] = @[]
    for f in manualIncludeFilesRaw:
      if f.len == 0: continue
      if os.isAbsolute(f): manualIncludeFiles.add(f)
      else: manualIncludeFiles.add(currDir / f)

    var jarr = newJArray()
    if autoInfo.sources.len > 0:
      for src in dedupPreserveOrder(autoInfo.sources & manualIncludeFiles):
        jarr.add(newJString(gypRelPath(src, addonPathDirectory)))
    elif fileExists(jsonConfigPath):
      # Fallback when auto-extraction found nothing but JSON exists:
      # previous behavior.
      let jsonConfigContents = parseJson(readFile(jsonConfigPath))
      if jsonConfigContents.hasKey("compile"):
        for elem in items(jsonConfigContents["compile"].elems):
          jarr.add(newJString(gypRelPath(elem[0].getStr(), addonPathDirectory)))
      for f in manualIncludeFiles:
        jarr.add(newJString(gypRelPath(f, addonPathDirectory)))
    else:
      for f in manualIncludeFiles:
        jarr.add(newJString(gypRelPath(f, addonPathDirectory)))

    # Set the source files in the `binding.gyp` configuration
    gyp["targets"][0]["sources"] = %* jarr

    # Forward include dirs / defines / cflags / link flags (auto + manual).
    var gypIncludes: seq[string] = @[]
    try:
      for e in gyp["targets"][0]["include_dirs"].elems:
        gypIncludes.add(e.getStr())
    except CatchableError:
      discard
    for d in @[cachePathDirectory] & autoInfo.includeDirs & manualIncludeDirs:
      if d notin gypIncludes:
        gypIncludes.add(d)
    var gypIncludesJson = newJArray()
    for d in gypIncludes:
      gypIncludesJson.add(newJString(d))
    gyp["targets"][0]["include_dirs"] = gypIncludesJson

    var gypDefines = newJArray()
    for d in dedupPreserveOrder(
        autoInfo.defines.mapIt(it.splitDefineForGyp()) &
        manualDefinesRaw.mapIt(
          if it.startsWith("-D") or it.startsWith("-U"): it.splitDefineForGyp()
          else: it)):
      gypDefines.add(newJString(d))
    if gypDefines.len > 0:
      gyp["targets"][0]["defines"] = gypDefines

    var gypCflags: seq[string] = @[]
    try:
      for e in gyp["targets"][0]["cflags"].elems:
        gypCflags.add(e.getStr())
    except CatchableError:
      discard
    for c in dedupPreserveOrder(autoInfo.compileOpts & manualCflags):
      if c notin gypCflags:
        gypCflags.add(c)
    var gypCflagsJson = newJArray()
    for c in gypCflags:
      gypCflagsJson.add(newJString(c))
    gyp["targets"][0]["cflags"] = gypCflagsJson
    gyp["targets"][0]["cflags_c"] = gypCflagsJson

    # Link flags: keep legacy `linkflags`, also populate standard
    # `libraries` / `ldflags` keys so the flags reach the linker
    # regardless of which key the toolchain honors.
    var gypLink: seq[string] = @[]
    try:
      for e in gyp["targets"][0]["linkflags"].elems:
        gypLink.add(e.getStr())
    except CatchableError:
      discard
    for l in dedupPreserveOrder(autoInfo.linkOpts & manualLinkFlags):
      if l notin gypLink:
        gypLink.add(l)
    var gypLinkJson = newJArray()
    for l in gypLink:
      gypLinkJson.add(newJString(l))
    gyp["targets"][0]["linkflags"] = gypLinkJson
    gyp["targets"][0]["libraries"] = gypLinkJson
    gyp["targets"][0]["ldflags"] = gypLinkJson

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

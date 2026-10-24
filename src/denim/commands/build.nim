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
import ../utils
import ../cli
import ../cmake

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
  if not s.contains({' ', '\t', '"', ';', '(', '#'}):
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

const pairFlags* = ["-arch", "-framework", "-isysroot", "-sysroot",
  "-F", "-L", "-Xlinker"]
  ## Compiler/linker flags that take a separate argument (e.g. `-arch arm64`).
  ## The argument is a bare token, so it must be kept together with its flag
  ## as two separate list items. Otherwise the flag dangles (e.g. `-arch`
  ## pairing with the next flag) or gets glued into one quoted CMake string
  ## (a single wrong argument instead of two).

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
        if tok in pairFlags and i + 1 < tokens.len and
           not tokens[i + 1].startsWith("-"):
          # Flags taking a separate argument: keep both tokens as two
          # separate items so CMake forwards two arguments.
          if tok notin result.compileOpts:
            result.compileOpts.add(tok)
          if tokens[i + 1] notin result.compileOpts:
            result.compileOpts.add(tokens[i + 1])
          i += 2
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
    let toks = splitShellCmd(cfg["linkcmd"].getStr())
    var i = 0
    while i < toks.len:
      let tok = toks[i]
      if tok in pairFlags and i + 1 < toks.len and
         not toks[i + 1].startsWith("-"):
        # Flags taking a separate argument (e.g. `-arch arm64`,
        # `-framework Security`): keep both tokens as two separate
        # items so CMake forwards two arguments. The argument is a bare
        # token, so the old take-every-`-flag` loop dropped it and left a
        # dangling flag that the linker paired with the next flag
        # (e.g. `-framework -ldl` -> framework "-ldl" not found).
        if tok notin result.linkOpts:
          result.linkOpts.add(tok)
        if toks[i + 1] notin result.linkOpts:
          result.linkOpts.add(toks[i + 1])
        i += 2
        continue
      if tok.startsWith("-"):
        if tok in ["-o", "-c"]:
          i += 1
          continue
        if tok.endsWith(".o") or tok.endsWith(".obj"):
          i += 1
          continue
        if tok notin result.linkOpts:
          result.linkOpts.add(tok)
      # object files / output binary are skipped
      i += 1

proc splitLinkFlags*(items: seq[string]): tuple[libs, flags: seq[string]] =
  ## Partition flat link tokens: pair-flag couples (`-arch <name>`,
  ## `-framework <Name>`, ...) become raw linker flags, everything else
  ## stays as libraries. `target_link_libraries` would rewrite a bare
  ## `Name` item to `-lName`, so couples must travel via
  ## `target_link_options` instead.
  result = (libs: @[], flags: @[])
  var i = 0
  while i < items.len:
    let tok = items[i]
    if tok in pairFlags and i + 1 < items.len and
       not items[i + 1].startsWith("-"):
      if tok notin result.flags:
        result.flags.add(tok)
      if items[i + 1] notin result.flags:
        result.flags.add(items[i + 1])
      i += 2
    else:
      if tok notin result.libs:
        result.libs.add(tok)
      inc i

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

# Internal CMake backend: the template is fully expanded by Denim
# (sources, include dirs, defines are baked in). No CMAKE_JS_* variables,
# no cmake-js npm dependency. Node headers are resolved by denim/cmake
# and prepended to DENIM_INCLUDE_DIRS by the build command below.
const cMakeListsContent = """
cmake_minimum_required(VERSION 3.15)
cmake_policy(SET CMP0091 NEW)
cmake_policy(SET CMP0042 NEW)

project (DENIM_PKG_NAME)

add_definitions(-DNAPI_VERSION=4 DENIM_DEFINES)

include_directories(DENIM_INCLUDE_DIRS)

set(SOURCE_FILES DENIM_EXPLICIT_SOURCES)

add_library(DENIM_PKG_NAME SHARED ${SOURCE_FILES})
set_target_properties(DENIM_PKG_NAME PROPERTIES LINKER_LANGUAGE CXX PREFIX "" SUFFIX ".node")
DENIM_COMPILE_OPTS_LINE
DENIM_PKG_LINK_LIBS
DENIM_PKG_LINK_OPTS_LINE
if(APPLE)
  target_link_libraries(DENIM_PKG_NAME "-framework Security")
endif()
"""

type BuildOptions* = object
  nimFile*: string
  y*: bool
  cmake*: bool
  generator*: string
  nodedir*: string
  includeDirs*: string
  includeFiles*: string
  defines*: string
  cflags*: string
  linkFlags*: string
  release*: bool
  verbose*: bool

proc buildCommand*(opts: BuildOptions) =
  ## Compile project to source code by using Nim compiler
  # https://nim-lang.org/docs/nimc.html
  let inputFile = opts.nimFile
  var
    currDir = getCurrentDir()
    addonPathDirectory = utils.getPath(currDir, "" / "denim_build")
    cachePathDirectory = addonPathDirectory / "nimcache"
    path = splitPath(inputFile)
    entryFile = path.tail
  if not entryFile.endsWith(".nim") or fileExists(inputFile) == false:
    display("Missing '.nim' file")
    quit(1)

  if not isEmptyDir(addonPathDirectory):
    if not opts.y:
      displayInfo("Directory is not empty: " & os.splitPath(addonPathDirectory).tail)
      if promptConfirm("Do you want to remove current contents? (y/N)"):
        os.removeDir(addonPathDirectory)
      else:
        display("Canceled")
        quit(1)
    else:
      os.removeDir(addonPathDirectory)
  displayInfo("Running Nim Compiler")
    
  var args = @[
    "--nimcache:$1",
    "--define:napibuild",
    "--compileOnly",
    "--noMain"
  ]
  if opts.release:
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
    quit(1)
  elif opts.verbose:
    display(nimCmd.output)
  let getNimPath = detectNimToolchainPath()
  if getNimPath.len == 0:
    displayError("Can't find Nim toolchain path (from `nim`/`nim dump`)")
    quit(1)
  discard execProcess("ln", args = [
    "-s",
    getNimPath / "lib" / "nimbase.h",
    cachePathDirectory
  ], options={poStdErrToStdOut, poUsePath})
  
  if opts.cmake:
    displayInfo("Building with CMake (internal, no cmake-js needed)")

    let jsonConfigPath = cachePathDirectory / entryFile.changeFileExt("json")
    let autoInfo = readNimBuildInfo(jsonConfigPath)

    # Manual overrides (all accept "a,b" or '["a","b"]').
    let manualIncludeDirs = parseStringList(opts.includeDirs)
    let manualIncludeFilesRaw = parseStringList(opts.includeFiles)
    let manualDefinesRaw = parseStringList(opts.defines)
    var manualCflags: seq[string] = @[]
    for entry in parseStringList(opts.cflags):
      for tok in splitShellCmd(entry):
        if tok.len > 0:
          manualCflags.add(tok)
    var manualLinkFlags: seq[string] = @[]
    for entry in parseStringList(opts.linkFlags):
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

    # Node headers: resolved locally (no downloads, no npm deps).
    # Override via --nodedir, NODE_HEADERS, or NODEDIR.
    let nodedirFlag = opts.nodedir
    let nodeHeaders = cmake.findNodeHeaders(nodedirFlag)
    if nodeHeaders.len == 0:
      displayError("Cannot find Node headers (node_api.h). " &
        "Install Node headers for your Node version or set --nodedir " &
        "(or NODE_HEADERS) to a directory containing node_api.h")
      quit(1)

    # Include dirs: Node headers first, then nimcache
    # (nimbase.h symlink lives here) + auto -I + manual.
    var allIncludeDirs = dedupPreserveOrder(
      @[nodeHeaders, cachePathDirectory] & autoInfo.includeDirs & manualIncludeDirs)
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
    # Pair-flag couples (-arch <name>, -framework <Name>) go through
    # target_link_options as raw flags; the rest stays libraries.
    var linkLibs = dedupPreserveOrder(autoInfo.linkOpts & manualLinkFlags)
    let (linkLibItems, linkFlagItems) = splitLinkFlags(linkLibs)
    var quotedLinkLibs: seq[string] = @[]
    for l in linkLibItems:
      quotedLinkLibs.add(cmakeQuote(l))
    let linkLibsLine =
      if quotedLinkLibs.len > 0:
        "target_link_libraries(" & pkgName & " " & quotedLinkLibs.join(" ") & ")"
      else: ""
    var quotedLinkFlags: seq[string] = @[]
    for f in linkFlagItems:
      quotedLinkFlags.add(cmakeQuote(f))
    let linkFlagsLine =
      if quotedLinkFlags.len > 0:
        "target_link_options(" & pkgName & " PRIVATE " & quotedLinkFlags.join(" ") & ")"
      else: ""
    writeFile(currDir / "CMakeLists.txt",
      cMakeListsContent.multiReplace(
        ("DENIM_EXPLICIT_SOURCES", quotedSources.join(" ")),
        ("DENIM_INCLUDE_DIRS", quotedIncludes.join(" ")),
        ("DENIM_DEFINES", escapedDefines.join(" ")),
        ("DENIM_COMPILE_OPTS_LINE", compileOptsLine),
        ("DENIM_PKG_NAME", pkgName),
        ("DENIM_PKG_LINK_LIBS", linkLibsLine),
        ("DENIM_PKG_LINK_OPTS_LINE", linkFlagsLine)
      )
    )
    # Build the native addon with the internal CMake driver
    # (no cmake-js npm dependency required, only a `cmake` binary).
    let generatorFlag = opts.generator
    let cmakeOpts = cmake.CmakeOptions(
      projectDir: currDir,
      workDir: addonPathDirectory / "build",
      config: "Release",
      generator: generatorFlag,
      nodedir: nodedirFlag,
      verbose: opts.verbose
    )
    if opts.verbose:
      displayInfo("CMake configure: " &
        cmake.getConfigureArgs(cmakeOpts).join(" "))
      displayInfo("CMake build: " &
        cmake.getBuildArgs(cmakeOpts).join(" "))
      displayInfo("Node headers: " & nodeHeaders)
    let cmakeRes = cmake.compile(cmakeOpts)
    if not cmakeRes.ok:
      display(cmakeRes.output)
      quit(1)
    if opts.verbose:
      display(cmakeRes.output)
  else:
    # When using `node-gyp`, we need to generate a `binding.gyp` file with
    # the correct configuration
    displayInfo("Building with node-gyp")
    var gyp = %* {"targets": [getNodeGypConfig(getNimPath, opts.release)]}
    let jsonConfigPath = cachePathDirectory / entryFile.replace(".nim", ".json")
    let autoInfo = readNimBuildInfo(jsonConfigPath)

    let manualIncludeDirs = parseStringList(opts.includeDirs)
    let manualIncludeFilesRaw = parseStringList(opts.includeFiles)
    let manualDefinesRaw = parseStringList(opts.defines)
    var manualCflags: seq[string] = @[]
    for entry in parseStringList(opts.cflags):
      for tok in splitShellCmd(entry):
        if tok.len > 0:
          manualCflags.add(tok)
    var manualLinkFlags: seq[string] = @[]
    for entry in parseStringList(opts.linkFlags):
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
      quit(1)
    if opts.verbose:
      display(gypCmd.output)
  let
    defaultBinName =
      if opts.cmake:
        entryFile.splitFile.name
      else: "main"
    binaryNodePath = utils.getPath(currDir, "" / "denim_build" / "build" / "Release" / defaultBinName & ".node")
    binDirectory = currDir / "bin"
    binName = entryFile.replace(".nim", ".node")
    binaryTargetPath = binDirectory / binName

  if fileExists(binaryNodePath) == false:
    displayError("Oups! $1 not found. Try build again" % [binName])
    quit(1)
  else:
    discard existsOrCreateDir(binDirectory)              # ensure bin directory exists
    moveFile(binaryNodePath, binaryTargetPath)           # move .node addon
    displaySuccess("Done! Check your `bin` directory")
    displayInfo(binDirectory)

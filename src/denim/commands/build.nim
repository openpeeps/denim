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
          # separate items so CMake forwards two arguments. Appended
          # unconditionally: identical couples repeat across compile
          # entries and are collapsed later by dedupFlagOpts.
          result.compileOpts.add(tok)
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
        # Appended unconditionally: identical couples are collapsed
        # later by dedupFlagOpts, which treats each couple as one unit.
        result.linkOpts.add(tok)
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

proc dedupFlagOpts*(items: seq[string]): seq[string] =
  ## Dedup a flat flag list, treating pair-flag couples (`-arch <name>`,
  ## `-framework <Name>`, ...) as one unit. Plain item-wise dedup would eat
  ## a repeated flag and orphan its argument (e.g. `-framework Security
  ## -framework CoreServices` collapsing to `-framework Security
  ## CoreServices`, where CMake rewrites the bare `CoreServices` to
  ## `-lCoreServices` and the link fails).
  result = @[]
  var seenPairs: seq[string] = @[]
  var i = 0
  while i < items.len:
    let tok = items[i]
    if tok in pairFlags and i + 1 < items.len and
       not items[i + 1].startsWith("-"):
      let key = tok & "\x1F" & items[i + 1]
      if key notin seenPairs:
        seenPairs.add(key)
        result.add(tok)
        result.add(items[i + 1])
      i += 2
    else:
      if tok notin result:
        result.add(tok)
      inc i

proc splitLinkFlags*(items: seq[string]): tuple[libs, flags: seq[string]] =
  ## Partition flat link tokens. `-framework <Name>` couples are glued
  ## into one item for `target_link_libraries` (CMake expands them to
  ## `-framework <Name>` on the link line, and distinct strings survive
  ## dedup). All other pair-flag couples go to `target_link_options` as
  ## separate raw items: CMake dedups repeated link-option items, so a
  ## repeated bare flag there would be swallowed and its argument
  ## misread (bare `Name` becomes `-lName`, bare `x86_64` an input file).
  result = (libs: @[], flags: @[])
  var i = 0
  var seenPairs: seq[string] = @[]
  while i < items.len:
    let tok = items[i]
    if tok in pairFlags and i + 1 < items.len and
       not items[i + 1].startsWith("-"):
      let key = tok & "\x1F" & items[i + 1]
      if key notin seenPairs:
        seenPairs.add(key)
        if tok == "-framework":
          let glued = tok & " " & items[i + 1]
          if glued notin result.libs:
            result.libs.add(glued)
        else:
          result.flags.add(tok)
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


# ---------------------------------------------------------------------------
# Dependency --path resolution (nimble/clue)
# ---------------------------------------------------------------------------
# Plain `nim c` only sees nimble's registry copies (~/.nimble/pkgs2) and
# knows nothing about clue's develop checkouts (~/.clue/develop) or
# clue-installed packages (~/.clue/packages). An entry file importing
# `pkg/<dep>` from a develop checkout then fails with "cannot open file".
# Resolve the project's dependency closure here and pass every package
# dir as --path, so bare `denim build` behaves like `clue task` (which
# injects the same paths via XDG_CONFIG_HOME).
#
# Per-package sources, in priority order:
#   1. ~/.clue/develop/<name> — live checkout wins (filesystem check).
#   2. clue's installed table (one `dbcheck` query for all packages);
#      stale rows (dir gone from disk) are skipped.
#   3. `nimble path <name>` — registry copies, first existing dir wins.
# URL requires (e.g. `requires "https://github.com/dfkup/stdlib"`) carry
# no package name; they are mapped through the local registry index
# (~/.clue/registries/*.json). Version constraints are NOT evaluated —
# the installed/develop copy is used as-is. A wrong pick surfaces as a
# Nim compile error (loud), never silently.

proc findProjectNimble*(startDir: string): string =
  ## Nearest .nimble walking up from startDir, "" when none.
  var dir = if startDir.len == 0: getCurrentDir() else: startDir
  while true:
    if dirExists(dir):
      for kind, path in walkDir(dir):
        if kind == pcFile and path.endsWith(".nimble"):
          return path
    let parent = parentDir(dir)
    if parent.len == 0 or parent == dir:
      return ""
    dir = parent

proc parseNimbleRequires*(nimbleFile: string): seq[string] =
  ## Raw requires entries: bare names (`vancode`), or full URLs.
  ## `nim` is skipped (toolchain, not a path). Indented lines are kept,
  ## so `feature`-gated requires resolve too (unused --paths are harmless).
  result = @[]
  try:
    for line in lines(nimbleFile):
      let t = line.strip()
      if not t.startsWith("requires "):
        continue
      var dep = t[len("requires ") .. ^1].strip().strip(chars = {'"', '\''})
      if dep.len == 0:
        continue
      if "://" in dep:
        result.add(dep) # URL — mapped to a name later
        continue
      var tok = dep.split(' ')[0].strip(chars = {'"', '\''})
      for sep in ["@", "#"]: # nimble `pkg@ver` / `pkg#branch` pins
        tok = tok.split(sep)[0]
      if tok.len == 0 or tok == "nim":
        continue
      result.add(tok)
  except IOError:
    discard

proc nimbleSrcDir*(nimbleFile: string): string =
  ## `srcDir` of a .nimble file, "src" when absent/unreadable.
  ## May be "" (flat layout) — the caller treats that as the root.
  result = "src"
  try:
    for line in lines(nimbleFile):
      let t = line.strip()
      if t.startsWith("srcDir"):
        let parts = t.split("=", 1)
        if parts.len == 2:
          return parts[1].strip().strip(chars = {'"', '\''})
  except IOError:
    discard

proc packageImportDir*(pkgRoot, pkgName: string): string =
  ## Import-ready dir for an installed package root: <root>/<srcDir>
  ## when it exists, else <root> (flat-layout packages). "" when the
  ## root is missing.
  if pkgRoot.len == 0 or not dirExists(pkgRoot):
    return ""
  var nimbleFile = pkgRoot / (pkgName & ".nimble")
  if not fileExists(nimbleFile):
    # Checkout dir name may differ from the package name.
    nimbleFile = ""
    for kind, path in walkDir(pkgRoot):
      if kind == pcFile and path.endsWith(".nimble"):
        nimbleFile = path
        break
  let srcDir = if nimbleFile.len > 0: nimbleSrcDir(nimbleFile) else: "src"
  if srcDir.len > 0:
    let cand = pkgRoot / srcDir
    if dirExists(cand):
      return cand
  return pkgRoot

proc clueDevelopDir*(name: string): string =
  ## Live checkout path (~/.clue/develop/<name>), "" when absent.
  ## The symlink itself is returned — the OS resolves it for --path.
  let dev = getHomeDir() / ".clue" / "develop" / name
  if dirExists(dev):
    return dev
  return ""

proc queryClueInstalled*(): seq[tuple[name, version, path: string]] =
  ## Whole installed table in one `dbcheck` call. @[] when clue is
  ## missing or the query fails (caller falls back to nimble).
  ## Exit code is ignored: only stdout JSON is trusted.
  result = @[]
  if findExe("clue").len == 0:
    return
  let q = execCmdEx("clue dbcheck 'SELECT name,version,path FROM installed' --json")
  try:
    let j = parseJson(q.output)
    for row in j["rows"].elems:
      result.add((row["name"].getStr(""), row["version"].getStr(""),
        row["path"].getStr("")))
  except CatchableError:
    discard

proc registryUrlName*(url: string): string =
  ## Map a URL require to a package name via the local registry index.
  ## "" when no registry cache or no match.
  let regDir = getHomeDir() / ".clue" / "registries"
  if not dirExists(regDir):
    return ""
  try:
    for kind, path in walkDir(regDir):
      if kind != pcFile or not path.endsWith(".json"):
        continue
      let j = parseJson(readFile(path))
      if j.kind != JArray:
        continue
      for e in j.elems:
        if e.kind == JObject and e["url"].getStr("") == url:
          let name = e["name"].getStr("")
          if name.len > 0:
            return name
  except CatchableError:
    discard
  return ""

proc nimblePackageDir*(name: string): string =
  ## First existing dir from `nimble path <name>`. "" when nimble is
  ## missing, the package unknown, or no listed dir exists.
  if findExe("nimble").len == 0:
    return ""
  let r = execCmdEx("nimble path " & name)
  for line in r.output.splitLines:
    let t = line.strip()
    if t.len > 0 and dirExists(t):
      return t
  return ""

proc cmpPkgVersion*(a, b: string): int =
  ## HEAD sorts above everything; else numeric per part.
  if a == b:
    return 0
  let ah = a == "HEAD" or a == "head"
  let bh = b == "HEAD" or b == "head"
  if ah and bh:
    return 0
  if ah:
    return 1
  if bh:
    return -1
  let ap = a.split('.')
  let bp = b.split('.')
  for i in 0 ..< max(ap.len, bp.len):
    var ai, bi = 0
    if i < ap.len:
      try:
        ai = parseInt(ap[i])
      except ValueError:
        discard
    if i < bp.len:
      try:
        bi = parseInt(bp[i])
      except ValueError:
        discard
    if ai != bi:
      return cmp(ai, bi)
  return 0

proc urlLastSegment*(url: string): string =
  ## Repo name of a URL require (`.../stdkups` -> `stdkups`, `.git`
  ## suffix stripped). Often equals the package name, which survives
  ## repo renames that the registry index has not caught up with.
  var u = url.strip()
  while u.endsWith("/"):
    u = u[0 .. ^2]
  let idx = max(u.rfind("/"), u.rfind(":"))
  result = if idx >= 0: u[idx + 1 .. ^1] else: u
  if result.endsWith(".git"):
    result = result[0 .. ^5]

proc resolveOnePackage*(name: string, installed: seq[tuple[name, version,
    path: string]], hasNimble: bool): tuple[root, dir: string] =
  ## Locate one package by name: live checkout, clue installs, nimble.
  ## ("", "") when unresolvable.
  result = ("", "")
  var root = clueDevelopDir(name)
  if root.len == 0:
    var bestPath = ""
    var bestVer = ""
    for row in installed:
      if row.name != name or not dirExists(row.path):
        continue
      if row.path.contains("/develop/") or row.path.contains("\\develop\\"):
        bestPath = row.path
        break
      if bestPath.len == 0 or cmpPkgVersion(row.version, bestVer) > 0:
        bestPath = row.path
        bestVer = row.version
    root = bestPath
  if root.len == 0 and hasNimble:
    root = nimblePackageDir(name)
  if root.len == 0:
    return result
  let dir = packageImportDir(root, name)
  if dir.len == 0:
    return result
  return (root, dir)

proc resolveDepPaths*(projectDir, entryFile: string): seq[string] =
  ## Full dependency closure of the project as import-ready dirs.
  ## Seeds are the project .nimble's requires (nearest .nimble above
  ## the entry file, else above the working dir). Transitive requires
  ## expand from each resolved package's own .nimble.
  result = @[]
  var start = projectDir
  try:
    start = parentDir(expandFilename(entryFile))
  except CatchableError:
    discard
  var nimbleFile = findProjectNimble(start)
  if nimbleFile.len == 0:
    nimbleFile = findProjectNimble(projectDir)
  if nimbleFile.len == 0:
    return result
  var queue = parseNimbleRequires(nimbleFile)
  var seen: seq[string] = @[]
  let installed = queryClueInstalled()
  let hasNimble = findExe("nimble").len > 0
  var resolved: seq[tuple[name, root, dir: string]] = @[]
  while queue.len > 0:
    let item = queue.pop()
    # Candidate names: a URL maps through the registry index first,
    # then falls back to its repo segment (survives repo renames the
    # registry has not caught up with).
    var candidates: seq[string] = @[]
    if "://" in item:
      if item in seen:
        continue
      seen.add(item)
      let viaRegistry = registryUrlName(item)
      if viaRegistry.len > 0:
        candidates.add(viaRegistry)
      let viaSegment = urlLastSegment(item)
      if viaSegment.len > 0 and viaSegment notin candidates:
        candidates.add(viaSegment)
      if candidates.len == 0:
        displayError("denim: cannot map URL requirement to a package name: " & item)
        continue
    else:
      if item in seen:
        continue
      seen.add(item)
      candidates.add(item)
    # First candidate that resolves wins; already-resolved names reuse
    # their cached dirs without re-expanding requires.
    var hit = -1
    for cand in candidates:
      for i, r in resolved:
        if r.name == cand:
          hit = i
          break
      if hit >= 0:
        break
      if cand in seen and cand != item:
        continue
      seen.add(cand)
      let r = resolveOnePackage(cand, installed, hasNimble)
      if r.dir.len > 0:
        resolved.add((cand, r.root, r.dir))
        hit = resolved.high
        var pkgNimble = r.root / (cand & ".nimble")
        if not fileExists(pkgNimble):
          pkgNimble = ""
          for kind, path in walkDir(r.root):
            if kind == pcFile and path.endsWith(".nimble"):
              pkgNimble = path
              break
        if pkgNimble.len > 0:
          for req in parseNimbleRequires(pkgNimble):
            queue.add(req)
        break
    if hit < 0:
      displayError("denim: cannot resolve package '" & item &
        "' (not found via clue or nimble)")
      continue
    if resolved[hit].dir notin result:
      result.add(resolved[hit].dir)
  return result


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

  # Dependency closure via nimble/clue (if found): every resolved package
  # dir lands on the import path, so `pkg/<dep>` works from develop
  # checkouts and clue installs without `clue task`.
  let depPaths = resolveDepPaths(currDir, inputFile)
  if depPaths.len > 0:
    displayInfo("Resolved " & $depPaths.len & " dependency paths (nimble/clue)")
  for depPath in depPaths:
    args.add("--path:\"" & depPath & "\"")

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
    let allCompileOpts = dedupFlagOpts(autoInfo.compileOpts & manualCflags)
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
    var linkLibs = dedupFlagOpts(autoInfo.linkOpts & manualLinkFlags)
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
    for c in dedupFlagOpts(autoInfo.compileOpts & manualCflags):
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
    for l in dedupFlagOpts(autoInfo.linkOpts & manualLinkFlags):
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

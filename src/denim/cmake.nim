# Node-API (N-API) bindings for Nim.
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/denim
#
# Internal CMake driver. Replaces the `cmake-js` npm dependency for
# `--cmake` builds. Only the subset Denim needs is implemented:
# NAPI addons, `node` runtime, local Node headers, POSIX (macOS/Linux).
# Windows returns a clear error (v1 scope, use node-gyp there).

import std/[os, osproc, strutils]
import std/cpuinfo

type
  CmakeOptions* = object
    projectDir*: string    ## Directory holding CMakeLists.txt (project root).
    workDir*: string       ## Build directory, e.g. <root>/denim_build/build.
    config*: string        ## CMake build type, e.g. "Release".
    generator*: string    ## "" means auto-detect.
    nodedir*: string      ## "" means auto-detect Node headers.
    verbose*: bool

  CmakeResult* = tuple[ok: bool, output: string]

proc cmakeBin*(): string =
  ## CMake binary, overridable via CMAKE_BIN.
  let e = getEnv("CMAKE_BIN")
  if e.len > 0: e else: "cmake"

proc isCmakeAvailable*(bin = ""): bool =
  let b = if bin.len > 0: bin else: cmakeBin()
  if fileExists(b):
    return true
  return findExe(b).len > 0

proc runCmd(cmd: seq[string], workDir: string): CmakeResult =
  ## Run a process without a shell. Returns (exitCode == 0, output).
  var parts: seq[string] = @[]
  for p in cmd:
    parts.add(quoteShell(p))
  let full = parts.join(" ")
  try:
    let r = execCmdEx(full, workingDir = workDir)
    return (r.exitCode == 0, r.output)
  except CatchableError as e:
    return (false, e.msg)

proc nodeQuery*(expr: string): string =
  ## Evaluate `node -p <expr>`, returning stdout stripped ("" on failure).
  if findExe("node").len == 0:
    return ""
  try:
    let r = execCmdEx("node -p " & quoteShell(expr),
      options = {poStdErrToStdOut, poUsePath})
    if r.exitCode != 0:
      return ""
    return r.output.strip()
  except CatchableError:
    return ""

proc nodeVersion*(): string =
  nodeQuery("process.versions.node")

proc nodeArch*(): string =
  nodeQuery("process.arch")

proc nodeExecPath*(): string =
  nodeQuery("process.execPath")

proc dedupStrings*(items: seq[string]): seq[string] =
  result = @[]
  for x in items:
    if x notin result:
      result.add(x)

proc candidateHeaderDir*(d: string): bool =
  d.len > 0 and fileExists(d / "node_api.h")

proc findNodeHeaders*(nodedir = ""): string =
  ## Locate a directory containing `node_api.h` using only local files.
  ## No downloads are performed. Returns "" when nothing is found.
  var candidates: seq[string] = @[]

  proc addFromPrefix(prefix: string) =
    if prefix.len == 0:
      return
    candidates.add(prefix / "include" / "node")
    candidates.add(prefix / "include")

  # 1. Explicit nodedir (matches node-gyp layout: <nodedir>/include/node).
  var explicit = nodedir.strip()
  if explicit.len == 0:
    explicit = getEnv("NODE_HEADERS").strip()
  if explicit.len == 0:
    explicit = getEnv("NODEDIR").strip()
  if explicit.len > 0:
    candidates.add(explicit / "include" / "node")
    candidates.add(explicit)
    candidates.add(explicit / "include")

  # 2. Prefix derived from the real node binary (handles fnm/nvm shims
  #    because process.execPath resolves to the real installation).
  let execPath = nodeExecPath()
  if execPath.len > 0:
    let binDir = parentDir(execPath)
    addFromPrefix(parentDir(binDir))

  # 3. Prefix derived from `which node` (symlink-resolved).
  let whichNode = findExe("node")
  if whichNode.len > 0:
    try:
      let realNode = expandSymlink(whichNode)
      let src = if realNode.len > 0: realNode else: whichNode
      addFromPrefix(parentDir(parentDir(src)))
    except CatchableError:
      discard

  # 4. Well-known system prefixes.
  for prefix in ["/usr/local", "/usr", "/opt/homebrew", "/opt/local"]:
    addFromPrefix(prefix)

  # 5. node-gyp header caches, keyed by running Node version.
  let ver = nodeVersion()
  if ver.len > 0:
    for cache in [getHomeDir() / ".node-gyp" / ver,
                  getHomeDir() / ".cache" / "node-gyp" / ver]:
      candidates.add(cache / "include" / "node")

  for c in dedupStrings(candidates):
    if candidateHeaderDir(c):
      return c
  return ""

proc detectGenerator*(preferred = ""): string =
  ## Pick a CMake generator. Explicit `--generator` wins, otherwise
  ## Ninja when available, else Unix Makefiles.
  if preferred.strip().len > 0:
    return preferred.strip()
  let envGen = getEnv("DENIM_GENERATOR").strip()
  if envGen.len > 0:
    return envGen
  if findExe("ninja").len > 0:
    return "Ninja"
  return "Unix Makefiles"

proc compilerFlags*(): seq[string] =
  ## Mirrors cmake-js toolset defaults for POSIX builds.
  result = @["-DBUILDING_NODE_EXTENSION"]
  when defined(macosx):
    result.add("-D_DARWIN_USE_64_BIT_INODE=1")
    result.add("-D_LARGEFILE_SOURCE")
    result.add("-D_FILE_OFFSET_BITS=64")

proc linkerFlags*(): seq[string] =
  when defined(macosx):
    # Kept as one entry like cmake-js (`-undefined dynamic_lookup`).
    return @["-undefined dynamic_lookup"]
  else:
    return @[]

proc osxArchFlag*(arch: string): string =
  ## Map Node arch names to CMAKE_OSX_ARCHITECTURES values.
  case arch
  of "x64": "x86_64"
  of "arm64": "arm64"
  else: ""

proc getConfigureArgs*(opts: CmakeOptions): seq[string] =
  let gen = detectGenerator(opts.generator)
  let buildDir = opts.workDir / opts.config
  result = @[cmakeBin(), opts.projectDir, "--no-warn-unused-cli"]
  result.add("-DCMAKE_BUILD_TYPE=" & opts.config)
  result.add("-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=" & buildDir)
  let cflags = compilerFlags().join(" ")
  if cflags.len > 0:
    result.add("-DCMAKE_C_FLAGS=" & cflags)
    result.add("-DCMAKE_CXX_FLAGS=" & cflags)
  let ldflags = linkerFlags().join(" ")
  if ldflags.len > 0:
    result.add("-DCMAKE_SHARED_LINKER_FLAGS=" & ldflags)
  when defined(macosx):
    let a = osxArchFlag(nodeArch())
    if a.len > 0:
      result.add("-DCMAKE_OSX_ARCHITECTURES=" & a)
  if gen.len > 0:
    result.add("-G")
    result.add(gen)

proc getBuildArgs*(opts: CmakeOptions, jobs = 0): seq[string] =
  result = @[cmakeBin(), "--build", opts.workDir, "--config", opts.config]
  let n = if jobs > 0: jobs else: cpuinfo.countProcessors()
  if n > 0:
    result.add("--parallel")
    result.add($n)

proc configure*(opts: CmakeOptions): CmakeResult =
  when defined(windows):
    return (false, "Internal --cmake backend supports macOS/Linux only in v1. " &
      "On Windows use node-gyp (omit --cmake) or install cmake-js.")
  else:
    if not isCmakeAvailable():
      return (false, "CMake executable not found. Install CMake 3.15+ " &
        "with your package manager (e.g. `brew install cmake`) or set CMAKE_BIN.")
    try:
      createDir(opts.workDir)
    except CatchableError as e:
      return (false, "Cannot create build directory " & opts.workDir & ": " & e.msg)
    return runCmd(getConfigureArgs(opts), opts.workDir)

proc isConfigured*(opts: CmakeOptions): bool =
  fileExists(opts.workDir / "CMakeCache.txt")

proc build*(opts: CmakeOptions): CmakeResult =
  when defined(windows):
    return (false, "Internal --cmake backend supports macOS/Linux only in v1. " &
      "On Windows use node-gyp (omit --cmake) or install cmake-js.")
  else:
    if not isCmakeAvailable():
      return (false, "CMake executable not found. Install CMake 3.15+.")
    if not isConfigured(opts):
      let c = configure(opts)
      if not c.ok:
        return c
    return runCmd(getBuildArgs(opts), opts.workDir)

proc clean*(opts: CmakeOptions): CmakeResult =
  try:
    if dirExists(opts.workDir):
      removeDir(opts.workDir)
    createDir(opts.workDir)
    return (true, "")
  except CatchableError as e:
    return (false, e.msg)

proc compile*(opts: CmakeOptions): CmakeResult =
  ## Configure + build, with a full rebuild fallback like `cmake-js compile`.
  when defined(windows):
    return (false, "Internal --cmake backend supports macOS/Linux only in v1. " &
      "On Windows use node-gyp (omit --cmake) or install cmake-js.")
  else:
    let first = build(opts)
    if first.ok:
      return first
    # Build failed: try a clean reconfigure + rebuild once.
    let c = clean(opts)
    if not c.ok:
      return (false, first.output & "\n[clean failed: " & c.output & "]")
    let rec = configure(opts)
    if not rec.ok:
      return (false, first.output & "\n[reconfigure failed: " & rec.output & "]")
    let second = runCmd(getBuildArgs(opts), opts.workDir)
    if second.ok:
      return second
    return (false, first.output & "\n[rebuild output: " & second.output & "]")

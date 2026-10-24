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

when defined napibuild:
  # Denim as a library exporting NAPI bindings
  import denim/nodeapi
  export nodeapi

elif isMainModule:
  # Denim as a CLI tool for building your Nim program to native Node addon
  # via the internal CMake driver (--cmake) or node-gyp (default).
  # Stdlib only, usage styling matches striptease.
  import std/[os, strutils]
  import ./denim/cli
  import ./denim/commands/build
  # import ./denim/commands/publish

  const buildStringOpts = ["--generator", "--nodedir", "--includeDirs",
    "--includeFiles", "--defines", "--cflags", "--linkFlags"]
  const buildKnownFlags = ["-y", "-r", "-h", "--help", "--version",
    "--cmake", "--verbose",
    "--generator", "--nodedir", "--includeDirs",
    "--includeFiles", "--defines", "--cflags", "--linkFlags"]

  proc printHelp() =
    echo grey("denim " & versionStr & " - Nim code to Node.js/Bun.js in seconds via NAPI") & "\n"
    echo grey("MIT license | Made by Humans from OpenPeeps\n  https://github.com/openpeeps/denim")
    echo ""
    echo "usage: denim <command> [options]"
    echo ""
    echo label("commands:")
    echo "  build <nim:file>      " & grey("build a native .node addon from Nim")
    # echo "  publish <addon:file>  " & grey("publish your addon (requires npm cli)")
    echo ""
    echo label("options:")
    echo "  -h, --help            " & grey("show this help")
    echo "  --version             " & grey("show version")

  proc printBuildHelp() =
    echo "usage: denim build <nim:file> [options]"
    echo ""
    echo label("arguments:")
    echo "  <nim:file>              " & grey("Nim entry file exporting NAPI bindings")
    echo ""
    echo label("options:")
    echo "  -y                      " & grey("remove an existing denim_build directory without asking")
    echo "  --cmake                 " & grey("use the internal CMake driver (faster, no npm deps)")
    echo "  --generator:<name>      " & grey("CMake generator (default: Ninja if available, else Unix Makefiles)")
    echo "  --nodedir:<dir>         " & grey("Node headers directory (or NODE_HEADERS env)")
    echo "  --includeDirs:<list>    " & grey("extra -I header search dirs")
    echo "  --includeFiles:<list>   " & grey("extra .c files to compile")
    echo "  --defines:<list>        " & grey("extra -D defines")
    echo "  --cflags:<flags>        " & grey("extra C compiler flags")
    echo "  --linkFlags:<flags>     " & grey("extra linker flags")
    echo "  -r                      " & grey("release build (-d:release --opt:speed)")
    echo "  --verbose               " & grey("print the Nim and CMake/node-gyp output")
    echo "  -h, --help              " & grey("show this help")

  # proc printPublishHelp() =
  #   echo "usage: denim publish <addon:file>"
  #   echo ""
  #   echo label("arguments:")
  #   echo "  <addon:file>  " & grey("compiled .node addon to publish (requires npm cli)")

  proc isKnownBuildFlag(arg: string): bool =
    var key = arg
    let eq = key.find('=')
    let colon = key.find(':')
    var sep = -1
    if eq > 0:
      sep = eq
    if colon > 0 and (sep < 0 or colon < sep):
      sep = colon
    if sep > 0:
      key = key[0 ..< sep]
    key in buildKnownFlags

  proc parseBuildArgs(params: seq[string], opts: var BuildOptions,
      wantHelp: var bool): string =
    ## Returns "" on success, else an error message. Accepts --key:value,
    ## --key=value and --key value forms.
    var i = 0
    var seenEnd = false
    while i < params.len:
      let arg = params[i]
      if seenEnd or arg == "-" or not arg.startsWith("-"):
        if opts.nimFile == "":
          opts.nimFile = arg
        else:
          return "only one input file allowed"
      elif arg == "--":
        seenEnd = true
      elif arg == "-y":
        opts.y = true
      elif arg == "-r":
        opts.release = true
      elif arg == "-h" or arg == "--help":
        wantHelp = true
      elif arg == "--cmake":
        opts.cmake = true
      elif arg == "--verbose":
        opts.verbose = true
      else:
        var key = arg
        var val = ""
        var attached = false
        let eq = arg.find('=')
        let colon = arg.find(':')
        var sep = -1
        if eq > 0:
          sep = eq
        if colon > 0 and (sep < 0 or colon < sep):
          sep = colon
        if sep > 0:
          key = arg[0 ..< sep]
          val = arg[sep + 1 .. ^1]
          attached = true
        if key in buildStringOpts:
          if not attached:
            if i + 1 < params.len and not isKnownBuildFlag(params[i + 1]):
              inc i
              val = params[i]
            else:
              return "option " & key & " needs a value"
          case key
          of "--generator":
            opts.generator = val
          of "--nodedir":
            opts.nodedir = val
          of "--includeDirs":
            opts.includeDirs = val
          of "--includeFiles":
            opts.includeFiles = val
          of "--defines":
            opts.defines = val
          of "--cflags":
            opts.cflags = val
          of "--linkFlags":
            opts.linkFlags = val
          else:
            discard
        elif key in ["--cmake", "--verbose", "-y", "-r", "-h", "--help", "--version"]:
          return "option " & key & " takes no value"
        else:
          return "unknown option " & key
      inc i
    return ""

  proc main(): int =
    let params = commandLineParams()
    if params.len == 0:
      printHelp()
      echo "\n" & errPrefix() & " a command is required"
      return 1
    let cmd = params[0]
    let rest = if params.len > 1: params[1 .. ^1] else: @[]
    case cmd
    of "-h", "--help":
      printHelp()
      return 0
    of "--version":
      echo versionStr
      return 0
    of "build":
      var opts = BuildOptions()
      var wantHelp = false
      let perr = parseBuildArgs(rest, opts, wantHelp)
      if wantHelp:
        printBuildHelp()
        return 0
      if perr != "":
        printBuildHelp()
        echo "\n" & errPrefix() & " " & perr
        return 1
      if opts.nimFile == "":
        printBuildHelp()
        echo "\n" & errPrefix() & " a nim file is required"
        return 1
      buildCommand(opts)
      return 0
      # of "publish":
      #   var addonFile = ""
      #   for a in rest:
      #     if a == "-h" or a == "--help":
      #       printPublishHelp()
      #       return 0
      #     elif a.startsWith("-"):
      #       echo errPrefix() & " unknown option " & a
      #       return 1
      #     elif addonFile == "":
      #       addonFile = a
      #     else:
      #       echo errPrefix() & " only one addon file allowed"
      #       return 1
      #   if addonFile == "":
      #     printPublishHelp()
      #     echo "\n" & errPrefix() & " an addon file is required"
      #     return 1
      #   publishCommand(addonFile)
      #   return 0
    else:
      echo errPrefix() & " unknown command " & cmd
      printHelp()
      return 1

  quit(main())

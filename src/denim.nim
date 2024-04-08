when defined napibuild:
  # Denim as a library exporting NAPI bindings
  import denimpkg/napi/bindings
  export bindings

elif isMainModule:
  # Denim as a CLI tool for building your Nim program to native Node addon
  # This requires latest version of `node-gyp`
  # todo add support for CMake.js 
  import kapsis
  import denimpkg/commands/[new, build, publish]

  # App:
    # about:
    #   "DENIM 🔥 Native Node/BunJS addons powered by Nim"
  commands:
    build file(`nim`), bool(-y), bool(--cmake), bool(-r), bool(--verbose):
      ## Build a native `node` addon from Nim
    publish file(`addon`):
      ## Publish your addon (requires npm cli)

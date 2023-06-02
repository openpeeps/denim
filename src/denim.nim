when isMainModule:
  import kapsis
  import denim/commands/[newCommand, buildCommand]

  App:
    about:
      "DENIM 🔥 Native Node/BunJS addons powered by Nim"

    commands:
      $ "build" `entry` "--release":
        ? "Build Nim project to a native NodeJS addon"
else:
  import denim/napi/bindings
  export bindings
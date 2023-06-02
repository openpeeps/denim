when defined denimcli:
  import kapsis
  import denimpkg/commands/[newCommand, buildCommand]

  App:
    about:
      "DENIM 🔥 Native Node/BunJS addons powered by Nim"

    commands:
      $ "build" `entry` "--release":
        ? "Build Nim project to a native NodeJS addon"
else:
  import denimpkg/napi/bindings
  export bindings
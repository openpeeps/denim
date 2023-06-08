when defined denimcli:
  import kapsis
  import denimpkg/commands/[newCommand, buildCommand]

  App:
    about:
      "DENIM 🔥 Native Node/BunJS addons powered by Nim"

    commands:
      $ "build" `entry` `links` "--release":
        ? "Build Nim project to a native NodeJS addon"
elif defined napibuild:
  import denimpkg/napi/bindings
  export bindings
when isMainModule:
  # Denim as a CLI tool for building your Nim program to native Node addon
  # This requires latest version of `node-gyp`
  # todo add support for CMake.js 
  import kapsis
  import denimpkg/commands/[newCommand, buildCommand, publishCommand]

  App:
    about:
      "DENIM 🔥 Native Node/BunJS addons powered by Nim"

    commands:
      $ "build" `entry` `links` "--release" "-y":
        ? "Build Nim project to a native NodeJS addon"
      $ "publish":
        ? "Publish addon to NPM (requires npm cli)"

elif defined napibuild:
  # Denim as a library exporting NAPI bindings
  import denimpkg/napi/bindings
  export bindings
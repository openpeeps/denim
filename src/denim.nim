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
  import denimpkg/nodeapi
  export nodeapi

elif isMainModule:
  # Denim as a CLI tool for building your Nim program to native Node addon
  # This requires latest version of `node-gyp`
  # todo add support for CMake.js 
  import kapsis
  import ./denimpkg/commands/[new, build, publish]

  initKapsis do:
    commands:
      build file(nim), ?bool("-y"), ?bool("--cmake"),
        ?string("--libs"), ?bool("-r"), ?bool("--verbose"):
        ## Build a native `node` addon from Nim
      publish file(addon):
        ## Publish your addon (requires npm cli)

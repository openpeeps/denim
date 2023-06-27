import denim
import std/json except `%*`

proc getWelcomeMessage(): string =
  return "Hello, World!"

init proc(module: Module) =
  module.registerFn(0, "getWelcomeMessage"):
    return %* getWelcomeMessage()

  proc hello(name: string): string {.export_napi.} =
    ## Nim comment to JS DocBlock!
    return %* args[0].getStr

  var settings: JsonNode = newJObject()
  settings["theme"] = newJString("dark")
  var defaultSettings {.export_napi.} = napiCall("JSON.parse", [%* $settings])

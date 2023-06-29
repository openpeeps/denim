import denim
import std/os
import std/json except `%*`

proc getWelcomeMessage(): string =
  return "Hello, World!"

type
  MySettings = object
    name, location: string
    age: int
    languages: seq[string]

init proc(module: Module) =

  proc getWelcomeMessage(name: string): string {.export_napi.} =
    # A high-level method to register and export functions
    # using `{.export_napi.}` pragma. Here we use `nnkProcDef`
    # to collect `nnkFormalParams` and create a type checker
    ## Nim comment to JS DocBlock!
    return %*(getWelcomeMessage() & " from Nim. " & args.get("name").getStr)

  proc toConsole(): string {.export_napi.} =
    return napiCall("console.log", [%*("okay")])

  # Expose an instance property. Here we'll use napiCall
  # to convert stringified JSON from Nim to NAPI via native `JSON.parse()`
  var settings: JsonNode = newJObject()
  settings["theme"] = newJString("dark")

  # add `exportSettings` instance to current module.
  # note that we can't use `const` to declare object instances
  # because `cannot evaluate at compile time: settings`
  var defaultSettings {.export_napi.} = napiCall("JSON.parse", [%* $settings])

  proc lowLevelStuff(a: bool) {.export_napi.} =
    if args[0].getBool == false:
      assert env.napi_throw(%*("Bad bad not good"))

  # Napi configurable, enumerable, writeable
  # https://nodejs.org/api/n-api.html#napi_create_object

  # Class
  # https://nodejs.org/api/n-api.html#napi_define_class
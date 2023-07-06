import denim
import std/strutils
import std/json except `%*`

init proc(module: Module) =

  proc parseInt(s: string) {.export_napi.} =
    return %* parseInt(args.get("s").getStr)

  proc parseJSON(s: string) {.export_napi.} =
    return %* $(parseJSON(args.get("s").getStr))
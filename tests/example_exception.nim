import denim
import std/strutils
import std/json except `%*`

type
  MyCatchableError = CatchableError

proc somethingWithErrors(x: int) =
  if x != 0:
    raise newException(MyCatchableError, "Trying to understand why " & $(x) & " and not 0")

init proc(module: Module) =

  proc parseInt(s: string) {.export_napi.} =
    return %* parseInt(args.get("s").getStr)

  proc parseJSON(s: string) {.export_napi.} =
    return %* $(parseJSON(args.get("s").getStr))

  proc myCatchable(i: int) {.export_napi.} =
    somethingWithErrors(args.get("i").getInt)
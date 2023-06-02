import std/[macros, json, strutils]

from std/strutils import contains, split
from std/sequtils import delete

import
  jsNativeApiTypes,
  jsNativeApi,
  nodeApi,
  utils

export jsNativeApiTypes, jsNativeApi, nodeApi

type
  NapiStatusError = object of CatchableError
  NapiErrorType* {.pure.} = enum
    napiError
    napiTypeError
    napiRangeError
    napiCustomError

var Env*: napi_env = nil
##Global environment variable; state maintained by various hooks; used internally

proc assert*(status: NapiStatus) {.raises: [NapiStatusError].} =
  ## Asserts that a call returns correctly;
  if status != napi_ok:
    raise newException(NapiStatusError, "NAPI call returned non-zero status (" & $status & ": " & $NapiStatus(status) & ")")

type Module* = ref object
  val*: napi_value
  env*: napi_env
  descriptors: seq[NapiPropertyDescriptor]

template error*(msg: cstring, code: cstring = "", errorType: NapiErrorType = napiError, customError: napi_value = nil): untyped =
  ## Throw an exception using `napi_throw_error`
  case errorType:
  of napiError:       Env.napi_throw_error(code, msg)
  of napiTypeError:   Env.napi_throw_type_error(code, msg)
  of napiRangeError:  Env.napi_throw_range_error(code, msg)
  of napiCustomError: Env.napi_throw(customError)

proc throwError*(env: napi_env, msg: cstring, code: cstring = cstring(""), errorType: NapiErrorType = napiError, customError: napi_value = nil): NapiStatus =
  case errorType:
  of napiError:       env.napi_throw_error(code, msg)
  of napiTypeError:   env.napi_throw_type_error(code, msg)
  of napiRangeError:  env.napi_throw_range_error(code, msg)
  of napiCustomError: env.napi_throw(customError)  

proc newNodeValue*(val: napi_value, env: napi_env): Module =
  ## Used internally, disregard
  Module(val: val, env: env, descriptors: @[])

proc kind(env: napi_env, val: napi_value): NapiValueType =
  assert ( napi_typeof(env, val, addr result) )

proc expect*(env: napi_env, n: napi_value, expectKind: NapiValueType): bool =
  return kind(env, n) == expectKind

proc expect*(env: napi_env, v: seq[napi_value], errorName = "", expectKind: varargs[(string, NapiValueType)]): bool =
  ## Check a seq of `napi_value` based on given `expectKind`.
  ## If not match will throw a `NapiErrorType` with the following message:
  ## ```Type mismatch parameter 'x'. Got 'A', expected 'B'```
  if v.len == expectKind.len:
    for i in 0 .. v.high:
      if kind(env, v[i]) != expectKind[i][1]:
        let msg = "Type mismatch parameter: `$1`. Got `$2`, expected `$3`" % [expectKind[i][0], $kind(env, v[i]), $expectKind[i][1]]
        assert env.throwError(cstring(msg), errorName.cstring)
        return
    return true
  var arglabel = "argument"
  if expectKind.len > 1: add arglabel, "s"
  assert error("This function requires $1 $2, $3 given" % [$expectKind.len, arglabel, $v.len], errorName)

proc create(env: napi_env, n: bool): napi_value =
  ## Create a new `Boolean` `napi_value`
  assert (napi_get_boolean(env, n, addr result))

proc create(env: napi_env, n: int32): napi_value =
  ## Create a new `int32` `napi_value`
  assert ( napi_create_int32(env, n, addr result) )

proc create(env: napi_env, n: int64): napi_value =
  ## Create a new `int64` `napi_value`
  assert ( napi_create_int64(env, n, addr result) )

proc create(env: napi_env, n: uint32): napi_value =
  ## Create a new `uint32` `napi_value`
  assert ( napi_create_uint32(env, n, addr result) )

proc create(env: napi_env, n: uint64): napi_value =
  ## Create a new `uint64` `napi_value`
  assert ( napi_create_uint64(env, n, addr result) )

proc create(env: napi_env, n: float64): napi_value =
  ## Create a new `float64` `napi_value`
  assert ( napi_create_double(env, n, addr result) )

proc create(env: napi_env, s: string): napi_value =
  ## Create a new `string` `napi_value`
  assert ( napi_create_string_utf8(env, s, s.len.csize_t, addr result) )

proc create(env: napi_env, p: openarray[(string, napi_value)]): napi_value =
  ## Create a new `object` `napi_value`
  assert napi_create_object(env, addr result)
  for name, val in items(p):
    assert napi_set_named_property(env, result, name, val)

proc create(env: napi_env, a: openarray[napi_value]): napi_value =
  ## Create a new `array` `napi_value`
  assert( napi_create_array_with_length(env, a.len.csize_t, addr result) )
  for i, elem in a.enumerate: assert napi_set_element(env, result, i.uint32, a[i])

proc create[T: int | uint | string](env: napi_env, a: openarray[T]): napi_value =
  var elements = newSeq[napi_value]()
  for elem in a: elements.add(env.create(elem))
  env.create(elements)

proc create[T: int | uint | string](env: napi_env, a: openarray[(string, T)]): napi_value =
  var properties = newSeq[(string, napi_value)]()
  for prop in a: properties.add((prop[0], create(prop[1])))
  env.create(a)

proc createFn*(env: napi_env, fname: string, cb: napi_callback): napi_value =
  ## Create a new function
  assert ( napi_create_function(env, fname, fname.len.csize_t, cb, nil, addr result) )

proc create(env: napi_env, v: napi_value): napi_value = v

proc create*[T](n: Module, t: T): napi_value =
  n.env.create(t)

proc kind*(val: napi_value): NapiValueType =
  kind(Env, val)

proc getInt64*(n: napi_value): int64 =
  ##Retrieves value from node; raises exception on failure
  assert napi_get_value_int64(Env, n, addr result)

proc getInt64*(n: napi_value, default: int64): int64 =
  ##Retrieves value from node; returns default on failure
  try: assert napi_get_value_int64(Env, n, addr result)
  except: result = default

proc getNull*: napi_value =
  ##Returns JavaScript ``null`` value
  assert napi_get_null(Env, addr result)

proc getUndefined*: napi_value =
  ##Returns JavaScript ``undefined`` value
  assert napi_get_undefined(Env, addr result)

proc getGlobal*: napi_value =
  ##Returns NodeJS global variable
  assert napi_get_global(Env, addr result)

proc getInt32*(n: napi_value): int32 =
  ##Retrieves value from node; raises exception on failure
  assert napi_get_value_int32(Env, n, addr result)

proc getInt32*(n: napi_value, default: int32): int32 =
  ##Retrieves value from node; returns default on failure
  try: assert napi_get_value_int32(Env, n, addr result)
  except: result = default

template getInt*(n: napi_value): int =
  ##Retrieves value from node based on bitness of architecture; raises exception on failure
  when sizeof(int) == 8:
    int(n.getInt64())
  else:
    int(n.getInt32())

template getInt*(n: napi_value, default: int): int =
  ##Retrieves value from node based on bitness of architecture; returns default on failure
  when sizeof(int) == 8:
    int(n.getInt64(default))
  else:
    int(n.getInt32(default))

proc getBool*(n: napi_value): bool =
  ##Retrieves value from node; raises exception on failure
  assert napi_get_value_bool(Env, n, addr result)

proc getBool*(n: napi_value, default: bool): bool =
  ##Retrieves value from node; returns default on failure
  try: assert napi_get_value_bool(Env, n, addr result)
  except: result = default

proc getStr*(n: napi_value): string =
  var bufSize: csize_t
  assert napi_get_value_string_utf8(Env, n, cast[cstring](nil), cast[csize_t](nil), addr bufSize)
  bufSize += 1
  var buf = cast[cstring](alloc(bufSize))
  defer: dealloc(buf)
  assert napi_get_value_string_utf8(Env, n, buf, bufSize, addr bufSize)
  return $buf

proc getStr*(n: napi_value, default: string, bufsize: int = 40): string =
  ## Retrieves utf8 encoded value from node; returns default on failure
  ## Maximum return string length is equal to ``bufsize``
  var
    buf = cast[cstring](alloc(bufsize))
    res: csize_t
  defer: dealloc(buf)
  try:
    assert napi_get_value_string_utf8(Env, n, buf, bufsize.csize_t, addr res)
    result = ($buf)[0..res-1]
  except: result = default

proc hasProperty*(obj: napi_value, key: string): bool {.raises: [ValueError, NapiStatusError].} =
  ##Checks whether or not ``obj`` has a property ``key``; Panics if ``obj`` is not an object
  if kind(obj) != napi_object: raise newException(ValueError, "value is not an object")
  assert napi_has_named_property(Env, obj, (key), addr result)

proc getProperty*(obj: napi_value, key: string):
  napi_value {.raises: [KeyError, ValueError, NapiStatusError].} =
  ## Retrieves property ``key`` from ``obj``;
  ## Panics if ``obj`` is not an object
  if not hasProperty(obj, key): raise newException(KeyError, "property not contained for key " & key)
  assert napi_get_named_property(Env, obj, (key), addr result)

proc getProperty*(obj: napi_value, key: string, default: napi_value): napi_value =
  ## Retrieves property ``key`` from ``obj``;
  ## returns default if ``obj`` is not an object or does not contain ``key``
  try: obj.getProperty(key)
  except: default

proc `[]`*(obj: napi_value, key: string): napi_value =
  ## Alias for ``getProperty``
  obj.getProperty(key)

proc get*(obj: napi_value, key: string): napi_value =
  ## Alias of `getProperty` for accessing a property from a specific object
  result = obj.getProperty(key)

proc get*(key: string): napi_value =
  ## Alias of `getProperty` for accessing global properties.
  ## This proc supports dot annotations `get("JSON.parse")`
  let globals = getGlobal()
  if key.contains("."):
    var keys = key.split(".")
    var prop: napi_value
    prop = globals.getProperty(keys[0])
    keys.delete(0)
    for k in keys:
      prop = prop.getProperty(k)
    result = prop
  else:
    result = globals.getProperty(key)

proc get*(key: string, default: napi_value): napi_value =
  ## Alias for `getProperty` with default support
  let globals = getGlobal()
  result = globals.getProperty(key, default)

proc setProperty*(obj: napi_value, key: string, value: napi_value)
  {.raises: [ValueError, NapiStatusError].}=
  ## Sets property ``key`` in ``obj`` to ``value``; raises exception if ``obj`` is not an object
  if kind(obj) != napi_object: raise newException(ValueError, "value is not an object")
  assert napi_set_named_property(Env, obj, key, value)

proc `[]=`*(obj: napi_value, key: string, value: napi_value) =
  ## Alias for ``setProperty``, raises exception
  obj.setProperty(key, value)


proc isArray*(obj: napi_value): bool =
  assert napi_is_array(Env, obj, addr result)

proc hasElement*(obj: napi_value, index: int): bool =
  ## Checks whether element is contained in ``obj``;
  ## raises exception if ``obj`` is not an array
  if not isArray(obj): raise newException(ValueError, "value is not an array")
  assert napi_has_element(Env, obj, uint32 index, addr result)

proc getElement*(obj: napi_value, index: int): napi_value =
  ##Retrieves value from ``index`` in  ``obj``;
  ## raises exception if ``obj`` is not an array or ``index`` is out of bounds
  if not hasElement(obj, index): raise newException(IndexDefect, "index out of bounds")
  assert napi_get_element(Env, obj, uint32 index, addr result)

proc getElement*(obj: napi_value, index: int, default: napi_value): napi_value =
  try: obj.getElement(index)
  except: default

proc setElement*(obj: napi_value, index: int, value: napi_value) =
  ##Sets value at ``index``; raises exception if ``obj`` is not an array
  if not isArray(obj): raise newException(ValueError, "value is not an array")
  assert napi_set_element(Env, obj, uint32 index, value)

proc len*(arr: napi_value): int =
  if not isArray(arr): raise newException(ValueError, "value is not an array")
  arr.getProperty("length").getInt

proc `[]`*(obj: napi_value, index: int): napi_value =
  ##Alias for ``getElement``; raises exception
  obj.getElement(index)
proc `[]=`*(obj: napi_value, index: int, value: napi_value) =
  ##Alias for ``setElement``; raises exception
  obj.setElement(index, value)

proc registerBase(obj: Module, name: string, value: napi_value, attr: int) =
  obj.descriptors.add(
    NapiPropertyDescriptor(
      utf8name: name,
      value: value,
      attributes: napi_default
    )
  )

proc register*[T: int | uint | string | napi_value](obj: Module,
  name: string, value: T, attr: int = 0) =
  ##Adds field to exports object ``obj``
  obj.registerBase(name, create(obj.env, value), attr)

proc register*[T: int | uint | string | napi_value](obj: Module,
  name: string, values: openarray[T], attr: int = 0) =
  ##Adds field to exports object ``obj``
  var elements =  newSeq[napi_value]()
  for v in values: elements.add(obj.create(v))

  obj.registerBase(name, create(obj.env, elements), attr)

proc register*[T: int | uint | string | napi_value](obj: Module,
  name: string, values: openarray[(string, T)], attr: int = 0) =
  ##Adds field to exports object ``obj``
  var properties = newSeq[(string, napi_value)]()
  for v in values: properties.add((v[0], obj.create(v[1])))

  obj.registerBase(name, create(obj.env, properties), attr)

proc register*(obj: Module, name: string, cb: napi_callback) =
  obj.registerBase(name, createFn(obj.env, name, cb), 0)

proc `%`*[T](t: T): napi_value =
  Env.create(t)

const emptyArr: array[0, (string, napi_value)] = []

proc callFunction*(fn: napi_value, args: openarray[napi_value] = [], this = %emptyArr): napi_value =
  ## Call a function by `napi_value` with given `args` and `this` context.
  assert napi_call_function(Env, this, fn,
    args.len.csize_t, cast[ptr napi_value](args.toUnchecked()), addr result)

proc callMethod*(instance: napi_value, methd: string, args: openarray[napi_value] = []): napi_value =
  ## Call a method from `instance` by name with given `args`
  assert napi_call_function(Env, instance, instance.getProperty(methd),
    args.len.csize_t, cast[ptr napi_value](args.toUnchecked()), addr result)

proc napiCall*(fname: string, args: openarray[napi_value] = []): napi_value {.discardable.} =
  ## A short-hand procedure for calling global `Napi` functions
  ## by string. You can use dot annotation for accessing and
  ## calling from object properties. For example `napiCall("JSON.parse", "{}")`
  let globals = getGlobal()
  if fname.contains("."):
    var keys = fname.split(".")
    var parentProp, prop: napi_value
    prop = globals.getProperty(keys[0])
    parentProp = prop
    keys.delete(0)
    for k in keys:
      prop = prop.getProperty(k)
    result = callFunction(prop, args, parentProp)
  else:
    result = callFunction(globals.getProperty(fname), args, globals)

proc tryGetJson*(n: napi_value): JsonNode =
  let data = napiCall("JSON.stringify", [n])
  result = parseJson(data.getStr)

template getIdentStr*(n: untyped): string = $n

template fn*(paramCt: int, name, cushy: untyped): untyped {.dirty.} =
  var name {.inject.}: napi_value
  block:
    proc `wrapper$`(environment: napi_env, info: napi_callback_info): napi_value {.cdecl.} =
      var
        `argv$` = cast[ptr UncheckedArray[napi_value]](alloc(paramCt * sizeof(napi_value)))
        argc: csize_t = paramCt
        this: napi_value
        args = newSeq[napi_value]()
      Env = environment
      assert napi_get_cb_info(environment, info, addr argc, `argv$`, addr this, nil)
      for i in 0..<min(argc, paramCt):
        args.add(`argv$`[][i])
      dealloc(`argv$`)
      cushy
    name = Env.createFn(name.getStr(), `wrapper$`)

template registerFn*(exports: Module, paramCt: int, name: string, cushy: untyped): untyped {.dirty.} =
  block:
    proc `wrapper$`(environment: napi_env, info: napi_callback_info): napi_value {.cdecl.} =
      var
        `argv$` = cast[ptr UncheckedArray[napi_value]](alloc(paramCt * sizeof(napi_value)))
        argc: csize_t = paramCt
        this: napi_value
        args = newSeq[napi_value]()
      Env = environment

      assert napi_get_cb_info(environment, info, addr argc, `argv$`, addr this, nil)
      for i in 0..<min(argc, paramCt):
        args.add(`argv$`[][i])
      dealloc(`argv$`)
      cushy
    exports.register(name, `wrapper$`)


proc defineProperties*(obj: Module) =
  assert napi_define_properties(obj.env, obj.val,
    obj.descriptors.len.csize_t,
    cast[ptr NapiPropertyDescriptor](obj.descriptors.toUnchecked)
  )

proc napiCreate*[T](t: T): napi_value =
  Env.create(t)

proc toNapiValue(x: NimNode): NimNode {.compiletime.} =
  case x.kind
  of nnkBracket:
    var brackets = newNimNode(nnkBracket)
    for i in 0..<x.len: brackets.add(toNapiValue(x[i]))
    newCall("napiCreate", brackets)
  of nnkTableConstr:
    var table = newNimNode(nnkTableConstr)
    for i in 0..<x.len:
      x[i].expectKind nnkExprColonExpr
      table.add newTree(nnkExprColonExpr, x[i][0], toNapiValue(x[i][1]))
    newCall("napiCreate", table)
  else:
    newCall("napiCreate", x)

macro `%*`*(x: untyped): untyped =
  return toNapiValue(x)


# Promise API


iterator items*(n: napi_value): napi_value =
  if not n.isArray: raise newException(ValueError, "value is not an array")
  for index in 0..<n.len:
    yield n[index]

# iterator pairs*(n: napi_value): napi_value =
#     for index in 0..<n.len:
#         yield n[index]

macro init*(initHook: proc(exports: Module)): void =
  ##Bootstraps module; use by calling ``register`` to add properties to ``exports``
  ##
  ##.. code-block:: Nim
  ##  init proc(exports: Module) =
  ##    exports.register("hello", "hello world")
  var nimmain = newProc(ident("NimMain"))
  nimmain.addPragma(ident("importc"))
  var cinit = newProc(
    name = ident("cinit"),
    params = [ident("napi_value") , newIdentDefs(ident("environment"), ident("napi_env")), newIdentDefs(ident("exportsPtr"), ident("napi_value"))],
    body = newStmtList(
      nimmain,
      newCall("NimMain"),
      newVarStmt(ident("exports"), newCall("newNodeValue", [ident("exportsPtr"), ident("environment")])),
      newAssignment(ident("Env"), ident("environment")),
      newCall(initHook, ident("exports")),
      newCall("defineProperties", ident("exports")),
      newNimNode(nnkReturnStmt).add(ident("exportsPtr"))
    )
  )
  cinit.addPragma(ident("exportc"))
  result = newStmtList(
    cinit,
    newNimNode(nnkPragma).add(newColonExpr(ident("emit"), newStrLitNode("""/*VARSECTION*/ NAPI_MODULE(NODE_GYP_MODULE_NAME, cinit)"""))),
  )
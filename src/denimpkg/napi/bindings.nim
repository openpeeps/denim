import std/[macros, json, strutils, sequtils, tables]
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

  Module* = ref object
    val*: napi_value
    env*: napi_env
    descriptors: seq[NapiPropertyDescriptor]

  TypedArg = tuple[str, argName, argType: string, argNapiValue: NapiValueType, isOptional: bool]

var
  Env*: napi_env = nil
    ## Global environment variable; state maintained by various hooks; used internally
  IndexModule = OrderedTableRef[string, seq[TypedArg]]()

proc assert*(status: NapiStatus) {.raises: [NapiStatusError].} =
  ## Asserts that a call returns correctly;
  if status != napi_ok:
    raise newException(NapiStatusError, "NAPI call returned non-zero status (" & $status & ": " & $NapiStatus(status) & ")")

template error*(msg: string, code = "", errorType: NapiErrorType = napiError, customError: napi_value = nil): untyped =
  ## Throw an exception using `napi_throw_error`
  case errorType:
  of napiError:       Env.napi_throw_error(code.cstring, msg.cstring)
  of napiTypeError:   Env.napi_throw_type_error(code.cstring, msg.cstring)
  of napiRangeError:  Env.napi_throw_range_error(code.cstring, msg.cstring)
  of napiCustomError: Env.napi_throw(customError)

proc throwError*(env: napi_env, msg: string, code = "", errorType: NapiErrorType = napiError, customError: napi_value = nil): NapiStatus =
  case errorType:
  of napiError:       env.napi_throw_error(code.cstring, msg.cstring)
  of napiTypeError:   env.napi_throw_type_error(code.cstring, msg.cstring)
  of napiRangeError:  env.napi_throw_range_error(code.cstring, msg.cstring)
  of napiCustomError: env.napi_throw(customError)  

# fwd
proc isArray*(obj: napi_value): bool


proc newNodeValue*(val: napi_value, env: napi_env): Module =
  ## Used internally, disregard
  Module(val: val, env: env, descriptors: @[])

proc kind(env: napi_env, val: napi_value): NapiValueType =
  assert ( napi_typeof(env, val, addr result) )

proc expect*(env: napi_env, n: napi_value, expectKind: NapiValueType): bool =
  return kind(env, n) == expectKind

proc expect*(env: napi_env, v: seq[napi_value], errorName, fnIdent: string): bool =
  result = true
  let exp = IndexModule[fnIdent]
  var index = "\n/*\n" & exp.map(proc(x: TypedArg): string = indent(x.str, 1)).join("\n")
  add index, "\n" & indent("*/", 1)
  for i in 0 .. exp.high:
    try:
      if kind(env, v[i]) != exp[i].argNapiValue or (exp[i].argType == "array" and v[i].isArray == false):
        let expectedType = if exp[i].argType == "array": "array" else: $exp[i].argNapiValue
        let errmsg = "Type mismatch parameter: `$1`. Got `$2`, expected `$3`" % [exp[i].argName, $kind(env, v[i]), expectedType]
        assert env.throwError(index & "\n" & errmsg, errorName)
        return
    except IndexDefect:
      if exp[i].isOptional:
        result = true
        continue
      else:
        let errmsg = "Type mismatch parameter: `$1`. Got `$2`, expected `$3`" % [exp[i].argName, $napi_undefined, $exp[i].argNapiValue]
        assert env.throwError(index & "\n" & errmsg, errorName)
        return false

  # if not result:
  #   var arglabel = "argument"
  #   if expectKind.len > 1: add arglabel, "s"
  #   assert env.throwError(fnDesc.docblock & "\n" & "This function requires $1 $2, $3 given" % [$expectKind.len, arglabel, $v.len], errorName)

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
  ## Create a new k/v `object` containing `napi_value`
  assert napi_create_object(env, addr result)
  for name, val in items(p):
    assert napi_set_named_property(env, result, name.cstring, val)

proc create(env: napi_env, p: seq[(string, napi_value)]): napi_value =
  ## Create a new k/v `object` containing `napi_value`
  assert napi_create_object(env, addr result)
  for name, val in items(p):
    assert napi_set_named_property(env, result, name.cstring, val)

proc create(env: napi_env, a: openarray[napi_value]): napi_value =
  ## Create a new `array` `napi_value`
  assert( napi_create_array_with_length(env, a.len.csize_t, addr result) )
  for i, elem in a.enumerate:
    assert napi_set_element(env, result, i.uint32, a[i])

proc create(env: napi_env, a: seq[napi_value]): napi_value =
  ## Create a new `array` `napi_value`
  assert( napi_create_array(env, addr result) )
  for i, elem in a.enumerate:
    assert napi_set_element(env, result, i.uint32, a[i])

proc create[T: int | uint | string](env: napi_env, a: openarray[T]): napi_value =
  ## Create a new `array`. Produce an array of `int`, `uint` `string` from `a
  var elements = newSeq[napi_value]()
  for elem in a:
    elements.add(env.create(elem))
  env.create(elements)

proc create[T](env: napi_env, a: seq[T]): napi_value =
  ## Create a new seq[seq[T]]. Produce an `napi_value` of type `array`
  ## containing one or more arrays.
  var elements = newSeq[napi_value]()
  for elem in a:
    elements.add(env.create(elem))
  env.create(elements)

proc create[T: int | uint | string](env: napi_env, a: openarray[(string, T)]): napi_value =
  var properties = newSeq[(string, napi_value)]()
  for prop in a:
    properties.add((prop[0], create(prop[1])))
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
  ## Returns JavaScript ``undefined`` value
  assert napi_get_undefined(Env, addr result)

proc undefined*: napi_value =
  ## Returns an `undefined` napi_value
  assert napi_get_undefined(Env, addr result) 

proc getGlobal*: napi_value =
  ## Returns NodeJS global variable
  assert napi_get_global(Env, addr result)

proc getInt32*(n: napi_value): int32 =
  ## Retrieves value from node; raises exception on failure
  assert napi_get_value_int32(Env, n, addr result)

proc getInt32*(n: napi_value, default: int32): int32 =
  ## Retrieves value from node; returns default on failure
  try: assert napi_get_value_int32(Env, n, addr result)
  except: result = default

template getInt*(n: napi_value): int =
  ## Return `int` value from `n`
  when sizeof(int) == 8:
    int(n.getInt64())
  else:
    int(n.getInt32())

template getInt*(n: napi_value, default: int): int =
  ## Return `int` value from `n`. Returns `default` on failure
  when sizeof(int) == 8:
    int(n.getInt64(default))
  else:
    int(n.getInt32(default))

proc getBool*(n: napi_value): bool =
  ## Return a `bool` value from `n`
  assert napi_get_value_bool(Env, n, addr result)

proc getBool*(n: napi_value, default: bool): bool =
  ## Return a `bool` from `n`. Returns `default` on failure
  try: assert napi_get_value_bool(Env, n, addr result)
  except: result = default

proc getStr*(n: napi_value): string =
  ## Return a `string` from `n`
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

proc setProperty*(obj: napi_value, key: string, value: napi_value) =
  ## Sets property ``key`` in ``obj`` to ``value``; raises exception if ``obj`` is not an object
  if kind(obj) != napi_object: raise newException(ValueError, "Value is not an object")
  assert napi_set_named_property(Env, obj, key, value)

proc `[]=`*(obj: napi_value, key: string, value: napi_value) =
  ## Alias for ``setProperty``, raises exception
  obj.setProperty(key, value)

proc isArray*(obj: napi_value): bool =
  assert napi_is_array(Env, obj, addr result)

proc hasElement*(obj: napi_value, index: int): bool =
  ## Checks whether element is contained in ``obj``;
  ## raises exception if ``obj`` is not an array
  if not isArray(obj): raise newException(ValueError, "Value is not an array")
  assert napi_has_element(Env, obj, uint32 index, addr result)

proc getElement*(obj: napi_value, index: int): napi_value =
  ##Retrieves value from ``index`` in  ``obj``;
  ## raises exception if ``obj`` is not an array or ``index`` is out of bounds
  if not hasElement(obj, index): raise newException(IndexDefect, "Index out of bounds")
  assert napi_get_element(Env, obj, uint32 index, addr result)

proc getElement*(obj: napi_value, index: int, default: napi_value): napi_value =
  try: obj.getElement(index)
  except: default

proc setElement*(obj: napi_value, index: int, value: napi_value) =
  ##Sets value at ``index``; raises exception if ``obj`` is not an array
  if not isArray(obj): raise newException(ValueError, "Value is not an array")
  assert napi_set_element(Env, obj, uint32 index, value)

proc len*(arr: napi_value): int =
  if not isArray(arr): raise newException(ValueError, "Value is not an array")
  arr.getProperty("length").getInt

proc `[]`*(obj: napi_value, index: int): napi_value =
  ## Alias for ``getElement``; raises exception
  obj.getElement(index)

proc `[]=`*(obj: napi_value, index: int, value: napi_value) =
  ## Alias for ``setElement``; raises exception
  obj.setElement(index, value)

proc registerBase(obj: Module, name: string, value: napi_value,
                attr: NapiPropertyAttributes = napi_default) =
  # https://nodejs.org/api/n-api.html#napi_property_descriptor
  obj.descriptors.add(
    NapiPropertyDescriptor(
      utf8name: name,
      value: value,
      attributes: attr
    )
  )

proc register*[T: int | uint | string | napi_value](obj: Module, name: string,
                value: T, attr: NapiPropertyAttributes = napi_default) =
  ## Adds field to exports object ``obj``
  obj.registerBase(name, create(obj.env, value), attr)

proc register*[T: int | uint | string | napi_value](obj: Module,
                name: string, values: openarray[T], attr: NapiPropertyAttributes = napi_default) =
  ## Adds field to exports object ``obj``
  var elements =  newSeq[napi_value]()
  for v in values: elements.add(obj.create(v))

  obj.registerBase(name, create(obj.env, elements), attr)

proc register*[T: int | uint | string | napi_value](obj: Module,
              name: string, values: openarray[(string, T)],
              attr: NapiPropertyAttributes = napi_default) =
  ## Register a new property field to `obj` Module.
  var properties = newSeq[(string, napi_value)]()
  for v in values: properties.add((v[0], obj.create(v[1])))

  obj.registerBase(name, create(obj.env, properties), attr)

proc register*(obj: Module, name: string, cb: napi_callback,
              attr: NapiPropertyAttributes = napi_default) =
  ## Register a new property field to `obj` Module.
  obj.registerBase(name, createFn(obj.env, name, cb), attr)

proc `%`*[T](t: T): napi_value =
  Env.create(t)

const emptyArr: array[0, (string, napi_value)] = []

proc callFunction*(fn: napi_value, args: openarray[napi_value] = [],
                  this = %emptyArr): napi_value =
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
  ## Register a function
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
  ## Register and export a function
  block:
    proc `wrapper$`(environment: napi_env, info: napi_callback_info): napi_value {.cdecl.} =
      var
        `argv$` = cast[ptr UncheckedArray[napi_value]](alloc(paramCt * sizeof(napi_value)))
        argc: csize_t = paramCt
        this: napi_value
        args = newSeq[napi_value]()
        env = environment
      Env = environment
      assert napi_get_cb_info(environment, info, addr argc, `argv$`, addr this, nil)
      for i in 0..<min(argc, paramCt):
        args.add(`argv$`[][i])
      dealloc(`argv$`)
      cushy
    exports.register(name, `wrapper$`)

proc napiCreate*[T](t: T): napi_value =
  ## Create a new `napi_value` of `T`
  Env.create(t)

proc toNapiValue(x: NimNode): NimNode {.compiletime.} =
  case x.kind
  of nnkBracket:
    var brackets = newNimNode(nnkBracket)
    for i in 0..<x.len: brackets.add(toNapiValue(x[i]))
    result = newCall("napiCreate", brackets)
  of nnkTableConstr:
    var table = newNimNode(nnkTableConstr)
    for i in 0..<x.len:
      x[i].expectKind nnkExprColonExpr
      table.add newTree(nnkExprColonExpr, x[i][0], toNapiValue(x[i][1]))
    result = newCall("napiCreate", table)
  else:
    case x.kind
    of nnkSym:
      case x.getType.kind
      of nnkObjectTy:
        # x.getTypeInst.repr
        # x.getType.repr
        let objStruct = x.getTypeImpl
        expectKind(objStruct[2], nnkRecList)
        var objFields = nnkBracket.newTree()
        for objField in objStruct[2]:
          case objField.kind:
          of nnkIdentDefs:
            objFields.add(
              nnkTupleConstr.newTree(
                newLit(objField[0].strVal),
                newCall("napiCreate", nnkDotExpr.newTree(x, objField[0]))
              )
            )
          else: discard # dont know what to do, yet
        result = newCall("napiCreate", objFields)
      else: result = newCall("napiCreate", x)
    else: result = newCall("napiCreate", x)

macro `%*`*(x: typed): untyped =
  ## An elegant way to convert Nim types to `napi_value`.
  runnableExamples:
    var nvStr: napi_value = %* "This is a string"
    var nvInt: napi_value = %* 1234
    var nvBool = %* true
  return toNapiValue(x)

proc addDocBlock*(fnName: string, args: openarray[(string, string, NapiValueType, bool)]) =
  # OrderedTableRef[string, tuple[argName, argValue: string, argNapiValue: napi_value, isOptional: bool]]
  IndexModule[fnName] = newSeq[TypedArg]()
  for arg in args:
    let jsCommentLine = "* @param {$1} $2" % [arg[1], arg[0]]
    add(IndexModule[fnName], (jsCommentLine, arg[0], arg[1], arg[2], arg[3]))

proc getNimNapiType(n: NimNode, countless: var bool): tuple[nimArgType, napiArgType: string] =
  if n.eqIdent("string"):
    # string > napi_string
    result = ("napi_string", n.strVal)
  elif n.eqIdent("bool"):
    # bool > napi_boolean
    result = ("napi_boolean", n.strVal)
  elif n.eqIdent("nil"):
    # nil > napi_null
    result = ("napi_null", n.strVal)
  elif n.eqIdent("int"):
    # int > napi_number
    result = ("napi_number", n.strVal)
  elif n.eqIdent("symbol"):
    # symbol > napi_symbol
    result = ("napi_symbol", "symbol")
  elif n.kind == nnkObjectTy:
    # object > napi_object
    result = ("napi_object", "object")
  elif n.kind == nnkProcTy:
    # func > napi_function
    result = ("napi_function", "func")
  elif n.eqIdent("array"):
    result = ("napi_object", "array")
  elif n.eqIdent("external"):
    result = ("napi_external", n.strVal)
  elif n.kind == nnkBracketExpr:
    if n[0].eqIdent("varargs"):
      countless = true
      result = getNimNapiType(n[1], countless)
  else:
    error("Cannot convert to NapiValueType", n)

macro export_napi*(vName, vType: untyped, vVal: typed) =
  ## A fancy compile-time macro to export object properties
  ## ```nim
  ## var name {.export_napi.} = "Denim is Awesome!"
  ## ```
  expectKind(vName, nnkIdent)
  result = newStmtList()
  result.add(
    newCall(
      ident("register"),
      ident("module"),
      newLit(vName.strVal),
      vVal
    )
  )

macro export_napi*(fn: untyped) =
  ## A fancy compile-time macro to export NAPI functions
  ## ```nim
  ## proc hello(name: string): string {.export_napi.} =
  ##   return %* args.get("name")
  ## ```
  expectKind(fn, nnkProcDef)
  expectKind(fn[6], nnkStmtList) # body
  expectKind(fn[3], nnkFormalParams) # params
  result = newStmtList()
  let fnName = fn[0].strVal
  var
    params = fn[3][1..^1]
    countless: bool # enabled when an argument has `varargs[]` type 
    args = newNimNode(nnkBracket)
    argsCond = nnkIfStmt.newTree()
  for i in 0 .. params.high:
    var typedArg = getNimNapiType(params[i][1], countless)
    var types = nnkTupleConstr.newTree(
      newLit(params[i][0].strVal),
      newLit(typedArg[1]),
      ident(typedArg[0]),
      newLit(false)
    )
    var argCond =
      nnkElifBranch.newTree(
        nnkInfix.newTree(ident("=="), ident("argName"), newLit(params[i][0].strVal)),
        nnkReturnStmt.newTree(
          nnkBracketExpr.newTree(ident("args"), newLit(i))
        )
      )
    add args, types
    add argsCond, argCond
  add result, newCall(ident("addDocBlock"), newLit(fnName), args)

  let
    callExpectProc = newCall(
      ident("expect"),
      ident("Env"),
      ident("args"),
      newLit(""),
      newLit(fnName)
    )
    typeChecker = newIfStmt(
      (
        nnkPrefix.newTree(ident("not"), callExpectProc),
        newStmtList(
          nnkReturnStmt.newTree(
            newEmptyNode()
          )
        )
      ))
  var
    fnBody = newStmtList()
    paramsLength = if countless: 100 else: params.len
  var argsGetterProc =
    newProc(
      ident("get"),
      [
        ident("napi_value"), # return type
        nnkIdentDefs.newTree(
          ident("args"),
          nnkBracketExpr.newTree(ident("seq"), ident("napi_value")),
          newEmptyNode()
        ),
        nnkIdentDefs.newTree(
          ident("argName"),
          ident("string"),
          newEmptyNode()
        )
      ],
      body = newStmtList(argsCond)
    )
  add fnBody, typeChecker
  add fnBody, argsGetterProc
  add fnBody, fn[6]
  result.add(
    newCall(
      ident("registerFn"),
      ident("module"),
      newLit(paramsLength),
      newLit(fnName),
      fnBody
    )
  )

#
# Promise - High-Level API
#
type
  AsyncActionStatus* = enum
    asyncActionSuccess
    asyncActionFail

  PromiseData*[T] = object
    status*: AsyncActionStatus
    deferred*: napi_deferred
    work*: napi_async_work
    jsData*: T

proc newPromiseData*[T](jsData: T): ref PromiseData[T] =
  new(result)
  result.jsData = jsData

macro promise*(fn: untyped) =
  fn # todo


iterator items*(n: napi_value): napi_value =
  if not n.isArray: raise newException(ValueError, "value is not an array")
  for index in 0..<n.len:
    yield n[index]

proc toSeq*(n: napi_value): seq[napi_value] =
  ## Return unpacked Array `object` to `seq[napi_value]`   
  if not n.isArray: raise newException(ValueError, "value is not an array")
  for i in n:
    add result, i

# iterator pairs*(n: napi_value): napi_value =
#     for index in 0..<n.len:
#         yield n[index]


proc defineProperties*(obj: Module) =
  assert napi_define_properties(obj.env, obj.val,
    obj.descriptors.len.csize_t,
    cast[ptr NapiPropertyDescriptor](obj.descriptors.toUnchecked)
  )

macro init*(initHook: proc(exports: Module)): void =
  ##Bootstraps module; use by calling `register` to add properties to `exports`
  ##
  ## ```nim
  ##  init proc(module: Module) =
  ##    module.register("hello", "hello world")
  ## ```
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
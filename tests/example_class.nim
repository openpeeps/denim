import denim
import std/json except `%*`

proc userHello(environment: napi_env, info: napi_callback_info): napi_value {.cdecl.} =
  Env = environment
  result = %* "Hello from User.hello()"

proc userCtor(environment: napi_env, info: napi_callback_info): napi_value {.cdecl.} =
  Env = environment
  var
    argc: csize_t = 0
    thisObj: napi_value

  # get `this` created by `new User()`
  assert environment.napi_get_cb_info(info, addr argc, nil, cast[napi_value](addr thisObj), nil)
  result = thisObj

init proc(module: Module) =
  var userClass: napi_value
  let classIdent = "User"
  var props = [
    NapiPropertyDescriptor(
      utf8name: "hello",
      `method`: userHello,
      attributes: napi_default
    )
  ]

  assert module.env.napi_define_class(classIdent,
    len(classIdent).csize_t, userCtor, nil,
    props.len.csize_t,
    cast[ptr NapiPropertyDescriptor](unsafeAddr props[0]),
    userClass.addr
  )

  module.register(classIdent, userClass)
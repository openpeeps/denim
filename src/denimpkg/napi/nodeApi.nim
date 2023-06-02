import macros
import nodeApiTypes, jsNativeApiTypes

export nodeApiTypes

proc napi_addon_register_func*(env: napi_env, exports: napi_value): napi_value {.header: "<node_api.h>".}

type NapiModule* {.importc: "napi_module", header:"<node_api.h>".} = object
  nm_version: cint
  nm_flags: cuint
  nm_filename: cstring
  nm_register_func: ptr napi_addon_register_func.typeof
  nm_modname: cstring
  nm_priv: pointer
  reserved: pointer

macro napiModule*(initHook: proc(env: napi_env, exports: napi_value)): void =
  var nimmain = newProc(ident("NimMain"))
  nimmain.addPragma(ident("importc"))

  var initFunc = newProc(
    name = ident("initfunc"),
    params = [
      ident("napi_value"), 
      newIdentDefs(ident("env"), ident("napi_env")),
      newIdentDefs(ident("exports"), ident("napi_value"))
    ],
    body = newStmtList(
      nimmain,
      newCall("NimMain"),
      newCall(initHook, ident("env"), ident("exports")),
      newNimNode(nnkReturnStmt).add(ident("exports"))
    )
  )
  initFunc.addPragma(ident("exportc"))
  result = newStmtList(
    initFunc,
    newNimNode(nnkPragma).add(newColonExpr(ident("emit"), newStrLitNode("""/*VARSECTION*/ NAPI_MODULE(NODE_GYP_MODULE_NAME, initfunc)""")))
  )
  echo result.toStrLit

{.push importc, header: "<node_api.h>".}
proc napi_module_register*(module: NapiModule)
proc napi_fatal_error*(location: cstring, location_len: csize_t, message: cstring, message_len: csize_t)

# Methods for custom handling of async operations
proc napi_async_init*(env: napi_env, async_resource: napi_value, async_resource_name: napi_value,
                        result: ptr napi_async_context): NapiStatus
proc napi_async_destroy*(env: napi_env, async_context: napi_async_context): NapiStatus
proc napi_make_callback*(env: napi_env, async_context: napi_async_context, recv: napi_value,
                        fn: napi_value, argc: csize_t, argv: ptr napi_value, result: ptr napi_value): NapiStatus

# Methods to provide node::Buffer functionality with napi types
proc napi_create_buffer*(env: napi_env, length: csize_t, data: ptr pointer, result: ptr napi_value): NapiStatus
proc napi_create_external_buffer*(env: napi_env, length: csize_t, data: pointer, finalize_cb: napi_finalize,
                                  finalize_hint: pointer, result: ptr napi_value): NapiStatus
proc napi_create_buffer_copy*(env: napi_env, length: csize_t, data: pointer, result_data: ptr pointer, result: ptr napi_value): NapiStatus
proc napi_is_buffer*(env: napi_env, value: napi_value, results: ptr bool): NapiStatus
proc napi_get_buffer_info*(env: napi_env, value: napi_value, data: ptr pointer, length: ptr csize_t): NapiStatus

# Methods to manage simple async operations
proc napi_create_async_work*(env: napi_env, async_resource: napi_value, async_resource_name: napi_value,
                          execute: napi_async_execute_callback.typeof, complete: napi_async_complete_callback.typeof,
                          data: pointer, result: ptr napi_async_work): NapiStatus
proc napi_delete_async_work*(env: napi_env, work: napi_async_work): NapiStatus
proc napi_queue_async_work*(env: napi_env, work: napi_async_work): NapiStatus
proc napi_cancel_async_work*(env: napi_env, work: napi_async_work): NapiStatus
# Version management
proc napi_get_node_version*(env: napi_env, version: ptr NapiNodeVersion): NapiStatus
{.pop.}
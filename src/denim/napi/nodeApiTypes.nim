import jsNativeApiTypes
type
  napi_callback_scope* {.header:"<node_api.h>".} = pointer
  napi_async_context* {.header:"<node_api.h>".} = pointer
  napi_async_work* {.header:"<node_api.h>".} = pointer
  napi_threadsafe_function* {.header:"<node_api.h>".} = pointer


proc napi_async_execute_callback*(env: napi_env, data: pointer): void {.header:"<node_api.h>".}
proc napi_async_complete_callback*(env: napi_env, status: NapiStatus, data: pointer): void {.header:"<node_api.h>".}


type NapiNodeVersion* {.importc:"napi_node_version", header: "<node_api.h>".} = object 
  major: uint32
  minor: uint32
  patch: uint32
  release: cstring

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

type
  napi_env* {.header:"<node_api.h>".} = pointer
  napi_value* {.header:"<node_api.h>".} = pointer
  napi_ref* {.header:"<node_api.h>".} = pointer
  napi_handle_scope* {.header:"<node_api.h>".} = pointer
  napi_escapable_handle_scope* {.header:"<node_api.h>".} = pointer
  napi_callback_info* {.header:"<node_api.h>".} = pointer
  napi_deferred* {.header:"<node_api.h>".} = pointer

  NapiPropertyAttributes* {.importc: "napi_property_attributes", header:"<node_api.h>".} = enum
    napi_default = 0
    napi_writable = 1 # 1 << 0
    napi_enumerable = 2 # 1 << 1
    napi_configurable = 4 # 1 << 2
    # Used with napi_define_class to distinguish static properties
    # from instance properties. Ignored by napi_define_properties.
    napi_static = 1024 # 1 << 10

  NapiValueType* {.importc: "napi_valuetype", header:"<node_api.h>".} = enum
    # ES6 types (corresponds to typeof)
    # https://nodejs.org/api/n-api.html#napi_valuetype
    napi_undefined = "undefined"
    napi_null = "null"
    napi_boolean = "boolean"
    napi_number = "number"
    napi_string = "string"
    napi_symbol = "symbol"
    napi_object = "object"
    napi_function = "function"
    napi_external = "external"
    napi_bigint = "bigint"

  NApiTypedArrayType* {.importc: "napi_typedarray_type", header:"<node_api.h>".} = enum
    napi_int8_array
    napi_uint8_array
    napi_uint8_clamped_array
    napi_int16_array
    napi_uint16_array
    napi_int32_array
    napi_uint32_array
    napi_float32_array
    napi_float64_array
    napi_bigint64_array
    napi_biguint64_array

  NapiStatus* {.importc: "napi_status", header:"<node_api.h>".} = enum
    napi_ok
    napi_invalid_arg
    napi_object_expected
    napi_string_expected
    napi_name_expected
    napi_function_expected
    napi_number_expected
    napi_boolean_expected
    napi_array_expected
    napi_generic_failure
    napi_pending_exception
    napi_cancelled
    napi_escape_called_twice
    napi_handle_scope_mismatch
    napi_callback_scope_mismatch
    napi_queue_full
    napi_closing
    napi_bigint_expected
    napi_date_expected
    napi_arraybuffer_expected
    napi_detachable_arraybuffer_expected

  NapiThreadSafeFunction* {.importc: "napi_threadsafe_function" header:"<node_api>".} = enum
    napi_tsfn_release
    napi_tsfn_abort

  napi_callback* = proc(environment: napi_env, info: napi_callback_info): napi_value {.cdecl.}
  napi_finalize* = proc(environment: napi_env, finalize_data, finalize_hint: pointer) {.cdecl.}
  napi_threadsafe_function_call_js* = proc(env: napi_env, js_callback: napi_value, context, data: pointer) {.cdecl.}
  
  NapiPropertyDescriptor* {.importc: "napi_property_descriptor", header:"<node_api.h>".} = object
    utf8name*: cstring
    name*, value*: napi_value
    attributes*: NApiPropertyAttributes
    `method`*, getter*, setter*: napi_callback
    data*: pointer

  NapiExtendedErrorInfo* {.importc: "napi_extended_error_info", header:"<node_api.h>".} = object
    error_message*: cstring
    engine_reserved*: pointer
    engine_error_code*: uint32
    error_code*: NapiStatus

{.push importc, header: "<node_api.h>".}
proc napi_get_last_error_info*(env: napi_env, result: UncheckedArray[NapiExtendedErrorInfo]): NapiStatus
# Getters for defined singletons
proc napi_get_undefined*(env: napi_env, result: ptr napi_value): NapiStatus
proc napi_get_null*(env: napi_env, result: ptr napi_value): NapiStatus
proc napi_get_global*(env: napi_env, result: ptr napi_value): NapiStatus
proc napi_get_boolean*(env: napi_env, value: bool, result: ptr napi_value): NapiStatus

# Methods to create Primitive types/Objects
proc napi_create_object*(env: napi_env, result: ptr napi_value): NapiStatus
proc napi_create_array*(env: napi_env, result: ptr napi_value): NapiStatus
proc napi_create_array_with_length*(env: napi_env, length: csize_t, result: ptr napi_value): NapiStatus
proc napi_create_double*(env: napi_env, value: float64, result: ptr napi_value): NapiStatus
proc napi_create_int32*(env: napi_env, value: int32, result: ptr napi_value): NapiStatus
proc napi_create_uint32*(env: napi_env, value: uint32, result: ptr napi_value): NapiStatus
proc napi_create_int64*(env: napi_env, value: int64, result: ptr napi_value): NapiStatus

# Not part of original api
proc napi_create_uint64*(env: napi_env, value: uint64, result: ptr napi_value): NapiStatus
proc napi_create_string_latin1*(env: napi_env, str: cstring, length: csize_t, result: ptr napi_value): NapiStatus
proc napi_create_string_utf8*(env: napi_env, str: cstring, length: csize_t, result: ptr napi_value): NapiStatus

# TODO napi_create_string_utf16 I'm not sure what the equivalent would be in nim
proc napi_create_symbol*(env: napi_env, description: napi_value, result: ptr napi_value): NapiStatus
proc napi_create_function*(env: napi_env, utf8name: cstring, length: csize_t, cb: napi_callback, data: pointer, result: ptr napi_value): NapiStatus 

proc napi_create_error*(env: napi_env, code: napi_value, msg: napi_value, result: ptr napi_value): NapiStatus
proc napi_create_type_error*(env: napi_env, code: napi_value, msg: napi_value, result: ptr napi_value): NapiStatus
proc napi_create_range_error*(env: napi_env, code: napi_value, msg: napi_value, result: ptr napi_value): NapiStatus

# Methods to get the native napi_value from Primitive type
proc napi_typeof*(env: napi_env, value: napi_value, result: ptr NapiValueType): NapiStatus

proc napi_get_value_double*(env: napi_env, value: napi_value, result: ptr float64): NapiStatus
proc napi_get_value_int32*(env: napi_env, value: napi_value, result: ptr int32): NapiStatus
proc napi_get_value_uint32*(env: napi_env, value: napi_value, result: ptr uint32): NapiStatus
proc napi_get_value_int64*(env: napi_env, value: napi_value, result: ptr int64): NapiStatus
proc napi_get_value_bool*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus

# Copies LATIN-1 encoded bytes from a string into a buffer.
proc napi_get_value_string_latin1*(env: napi_env, value: napi_value, buf: cstring, bufsize: csize_t, result: ptr csize_t): NapiStatus
#Copies UTF-8 encoded bytes from a string into a buffer.
proc napi_get_value_string_utf8*(env: napi_env, value: napi_value, buf: cstring, bufsize: csize_t, result: ptr csize_t): NapiStatus
# TODO napi_get_value_string_utf16

# Methods to coerce values
# These APIs may execute user scripts
proc napi_coerce_to_bool*(env: napi_env, value: napi_value, result: ptr napi_value): NapiStatus
proc napi_coerce_to_number*(env: napi_env, value: napi_value, result: ptr napi_value): NapiStatus
proc napi_coerce_to_object*(env: napi_env, value: napi_value, result: ptr napi_value): NapiStatus
proc napi_coerce_to_string*(env: napi_env, value: napi_value, result: ptr napi_value): NapiStatus


# Methods to work with Objects
proc napi_get_prototype*(env: napi_env, obj: napi_value, result: ptr napi_value): NapiStatus
proc napi_get_property_names*(env: napi_env, obj: napi_value, result: ptr napi_value): NapiStatus
proc napi_set_property*(env: napi_env, obj: napi_value, key: napi_value, value: napi_value): NapiStatus
proc napi_has_property*(env: napi_env, obj: napi_value, key: napi_value, result: ptr bool): NapiStatus
proc napi_get_property*(env: napi_env, obj: napi_value, key: napi_value, result: ptr napi_value): NapiStatus
proc napi_delete_property*(env: napi_env, obj: napi_value, key: napi_value, result: ptr bool): NapiStatus
proc napi_has_own_property*(env: napi_env, obj: napi_value, key: napi_value, result: ptr bool): NapiStatus
proc napi_set_named_property*(env: napi_env, obj: napi_value, utf8name: cstring, value: napi_value): NapiStatus
proc napi_has_named_property*(env: napi_env, obj: napi_value, utf8name: cstring, result: ptr bool): NapiStatus
proc napi_get_named_property*(env: napi_env, obj: napi_value, utf8name: cstring, result: ptr napi_value): NapiStatus
proc napi_set_element*(env: napi_env, obj: napi_value, index: uint32, value: napi_value): NapiStatus
proc napi_has_element*(env: napi_env, obj: napi_value, index: uint32, result: ptr bool): NapiStatus
proc napi_get_element*(env: napi_env, obj: napi_value, index: uint32, result: ptr napi_value): NapiStatus
proc napi_delete_element*(env: napi_env, obj: napi_value, index: uint32, result: ptr bool): NapiStatus
proc napi_define_properties*(env: napi_env, obj: napi_value, property_count: csize_t, properties: ptr NapiPropertyDescriptor): NapiStatus

# Methods to work with Arrays
proc napi_is_array*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus
proc napi_get_array_length*(env: napi_env, value: napi_value, result: ptr uint32): NapiStatus
# Methods to compare values
proc napi_strict_equals*(env: napi_env, lhs: napi_value, rhs: napi_value, result: ptr bool): NapiStatus
# Methods to work with Functions
proc napi_call_function*(env: napi_env, recv: napi_value, fn: napi_value, argc: csize_t, argv: ptr napi_value, result: ptr napi_value): NapiStatus
proc napi_new_instance*(env: napi_env, constructor: napi_value, argc: csize_t, argv: ptr napi_value, result: ptr napi_value): NapiStatus
proc napi_instanceof*(env: napi_env, obj: napi_value, constructor: napi_value, result: ptr bool): NapiStatus

# Methods to work with napi_callbacks

# Gets all callback info in a single call. (Ugly, but faster.)
proc napi_get_cb_info*(
  env: napi_env,
  cbinfo: napi_callback_info,
  argc: ptr csize_t,
  argv: ptr UncheckedArray[napi_value],
  this_arg: napi_value,
  data: ptr pointer): NapiStatus 

proc napi_get_new_target*(env: napi_env, cbinfo: napi_callback_info, result: ptr napi_value): NapiStatus 

proc napi_define_class*(
  env: napi_env,
  utf8name: cstring,
  length: csize_t,
  constructor: napi_callback,
  data: pointer,
  property_count: csize_t,
  properties: ptr NapiPropertyDescriptor,
  result: ptr napi_value): NapiStatus 

# Methods to work with external data objects
proc napi_wrap*(env: napi_env, js_object: napi_value, native_object: pointer, finalize_cb: napi_finalize, finalize_hint: pointer, result: ptr napi_ref): NapiStatus
proc napi_unrwap*(env: napi_env, js_object: napi_value, result: ptr pointer): NapiStatus
proc napi_remove_wrap*(env: napi_env, js_object: napi_value, result: ptr pointer): NapiStatus
proc napi_create_external*(env: napi_env, data: pointer, finalize_cb: napi_finalize, finalize_hint: pointer, result: ptr napi_value): NapiStatus
proc napi_get_value_external*(env: napi_env, value: napi_value, result: ptr pointer): NapiStatus

# TODO: Add "Methods to control object lifespan"
proc napi_open_handle_scope*(env: napi_env, scope: ptr napi_handle_scope): NapiStatus
proc napi_create_reference*(env: napi_env, value: napi_value, initial_refcount: uint32, res: ptr napi_ref): NapiStatus
proc napi_get_reference_value*(env: napi_env, nref: napi_ref, res: ptr napi_value): NapiStatus

# Methods to support error handling
proc napi_throw*(env: napi_env, error: napi_value): NapiStatus
proc napi_throw_error*(env: napi_env, code: cstring, msg: cstring): NapiStatus
proc napi_throw_type_error*(env: napi_env, code: cstring, msg: cstring): NapiStatus
proc napi_throw_range_error*(env: napi_env, code: cstring, msg: cstring): NapiStatus
proc napi_is_error*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus

# Methods to support catching exceptions
proc napi_is_exception_pending*(env: napi_env, result: ptr bool): NapiStatus
proc napi_get_and_clear_last_exception*(env: napi_env, result: ptr napi_value): NapiStatus

# Methods to work with array buffers and typed arrays
proc napi_is_arraybuffer*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus

proc napi_create_arraybuffer*(
  env: napi_env, 
  byte_length: csize_t,
  data: ptr pointer,
  result: ptr napi_value): NapiStatus

proc napi_create_external_arraybuffer*(
  env: napi_env,
  external_data: pointer,
  byte_length: csize_t,
  finalize_cb: napi_finalize,
  finalize_hint: pointer,
  result: ptr napi_value): NapiStatus

proc napi_get_arraybuffer_info*(
  env: napi_env, 
  arraybuffer: napi_value,
  data: ptr pointer,
  byte_length: ptr csize_t): NapiStatus

proc napi_is_typedarray*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus
proc napi_create_typedarray*(env: napi_env, array_type: NApiTypedArrayType, length: csize_t, arraybuffer: napi_value, byte_offset: csize_t, result: ptr napi_value): NapiStatus
proc napi_get_typedarray_info*( env: napi_env, typedarray: napi_value, array_type: ptr NApiTypedArrayType, length: ptr csize_t, data: ptr pointer, arraybuffer: ptr napi_value, byte_offset: csize_t): NapiStatus
proc napi_create_dataview*(env: napi_env, length: csize_t, arraybuffer: napi_value, byte_offset: csize_t, result: ptr napi_value): NapiStatus
proc napi_is_dataview*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus
proc napi_get_dataview_info*(env: napi_env, dataview: napi_value, byte_length: ptr csize_t, data: ptr pointer, arraybuffer: ptr napi_value, byte_offset: ptr csize_t): NapiStatus

# Version management
proc napi_get_version*(env: napi_env, result: ptr uint32): NapiStatus

# Promises
proc napi_create_promise*(env: napi_env, deffered: ptr napi_deferred, promise: ptr napi_value): NapiStatus
proc napi_resolve_deferred*(env: napi_env, deffered: napi_deferred, resolution: napi_value): NapiStatus
proc napi_reject_deferred*(env: napi_env, deffered: napi_deferred, rejection: napi_value): NapiStatus
proc napi_is_promise*(env: napi_env, promise: napi_value, is_promise: ptr bool): NapiStatus
# Running a script
proc napi_run_script*(env: napi_env, script: napi_value, result: ptr napi_value): NapiStatus
# Memory management
proc napi_adjust_external_memory*(env: napi_env, change_in_bytes: int64, adjusted_value: ptr int64): NapiStatus

# Dates
proc napi_create_date*(env: napi_env, time: float64, result: ptr napi_value): NapiStatus
proc napi_is_date*(env: napi_env, value: napi_value, is_date: ptr bool): NapiStatus
proc napi_get_date_value*(env: napi_env, value: napi_value, result: ptr float64): NapiStatus

proc napi_add_finalizer*(env: napi_env, js_object: napi_value, native_object: pointer, finalize_cb: napi_finalize, finalize_hint: pointer, result: ptr napi_ref): NapiStatus
{.pop.}
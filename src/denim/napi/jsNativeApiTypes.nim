type
  napi_env* {.header:"<node_api.h>".} = pointer
  napi_value* {.header:"<node_api.h>".} = pointer
  napi_ref* {.header:"<node_api.h>".} = pointer
  napi_handle_scope* {.header:"<node_api.h>".} = pointer
  napi_escapable_handle_scope* {.header:"<node_api.h>".} = pointer
  napi_callback_info* {.header:"<node_api.h>".} = pointer
  napi_deferred* {.header:"<node_api.h>".} = pointer

type NApiPropertyAttributes* {.importc: "napi_property_attributes", header:"<node_api.h>".} = enum
  napi_default = 0
  napi_writable = 1 # 1 << 0
  napi_enumerable = 2 # 1 << 1
  napi_configurable = 4 # 1 << 2

  # Used with napi_define_class to distinguish static properties
  # from instance properties. Ignored by napi_define_properties.
  napi_static = 1024 # 1 << 10

type NapiValueType* {.importc: "napi_valuetype", header:"<node_api.h>".} = enum
  # ES6 types (corresponds to typeof)
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

type NApiTypedArrayType* {.importc: "napi_typedarray_type", header:"<node_api.h>".} = enum
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

type NapiStatus* {.importc: "napi_status", header:"<node_api.h>".} = enum
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

type napi_callback* = proc(environment: napi_env, info: napi_callback_info): napi_value {.cdecl.}

type napi_finalize* = proc(environment: napi_env, finalize_data, finalize_hint: pointer): void {.cdecl.}

type NapiPropertyDescriptor* {.importc: "napi_property_descriptor", header:"<node_api.h>".} = object
  utf8name*: cstring
  name*, value*: napi_value
  attributes*: NApiPropertyAttributes
  `method`*, getter*, setter*: napi_callback
  data*: pointer

type NapiExtendedErrorInfo* {.importc: "napi_extended_error_info", header:"<node_api.h>".} = object
  error_message*: cstring
  engine_reserved*: pointer
  engine_error_code*: uint32
  error_code*: NapiStatus

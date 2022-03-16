import jsNativeApiTypes

proc napi_get_last_error_info*(env: napi_env, result: UncheckedArray[NapiExtendedErrorInfo]):
    NapiStatus {.header: "<node_api.h>".}

# Getters for defined singletons
proc napi_get_undefined*(env: napi_env, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_null*(env: napi_env, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_global*(env: napi_env, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_boolean*(env: napi_env, value: bool, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}


# Methods to create Primitive types/Objects
proc napi_create_object*(env: napi_env, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_array*(env: napi_env, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_array_with_length*(env: napi_env, length: csize_t, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_double*(env: napi_env, value: float64, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_int32*(env: napi_env, value: int32, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_uint32*(env: napi_env, value: uint32, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_int64*(env: napi_env, value: int64, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

# Not part of original api
proc napi_create_uint64*(env: napi_env, value: uint64, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_string_latin1*(env: napi_env, str: cstring, length: csize_t, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_string_utf8*(env: napi_env, str: cstring, length: csize_t, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

# TODO napi_create_string_utf16 I'm not sure what the equivalent would be in nim
proc napi_create_symbol*(env: napi_env, description: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_function*(env: napi_env, utf8name: cstring, length: csize_t, cb: napi_callback,
    data: pointer, result: ptr napi_value): NapiStatus {.header:"<node_api.h>".}

proc napi_create_error*(env: napi_env, code: napi_value, msg: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_type_error*(env: napi_env, code: napi_value, msg: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_create_range_error*(env: napi_env, code: napi_value, msg: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}



# Methods to get the native napi_value from Primitive type
proc napi_typeof*(env: napi_env, value: napi_value, result: ptr NapiValueType):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_value_double*(env: napi_env, value: napi_value, result: ptr float64):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_value_int32*(env: napi_env, value: napi_value, result: ptr int32):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_value_uint32*(env: napi_env, value: napi_value, result: ptr uint32):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_value_int64*(env: napi_env, value: napi_value, result: ptr int64):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_value_bool*(env: napi_env, value: napi_value, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}

# Copies LATIN-1 encoded bytes from a string into a buffer.
proc napi_get_value_string_latin1*(env: napi_env, value: napi_value, buf: cstring,
    bufsize: csize_t, result: ptr csize_t): NapiStatus {.header: "<node_api.h>".}

#Copies UTF-8 encoded bytes from a string into a buffer.
proc napi_get_value_string_utf8*(env: napi_env, value: napi_value, buf: cstring,
    bufsize: csize_t, result: ptr csize_t): NapiStatus {.header: "<node_api.h>".}
# TODO napi_get_value_string_utf16



# Methods to coerce values
# These APIs may execute user scripts
proc napi_coerce_to_bool*(env: napi_env, value: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_coerce_to_number*(env: napi_env, value: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_coerce_to_object*(env: napi_env, value: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_coerce_to_string*(env: napi_env, value: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}




# Methods to work with Objects
proc napi_get_prototype*(env: napi_env, obj: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_property_names*(env: napi_env, obj: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_set_property*(env: napi_env, obj: napi_value, key: napi_value, value: napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_has_property*(env: napi_env, obj: napi_value, key: napi_value, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_property*(env: napi_env, obj: napi_value, key: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_delete_property*(env: napi_env, obj: napi_value, key: napi_value, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}

proc napi_has_own_property*(env: napi_env, obj: napi_value, key: napi_value, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}

proc napi_set_named_property*(env: napi_env, obj: napi_value, utf8name: cstring, value: napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_has_named_property*(env: napi_env, obj: napi_value, utf8name: cstring, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_named_property*(env: napi_env, obj: napi_value, utf8name: cstring, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_set_element*(env: napi_env, obj: napi_value, index: uint32, value: napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_has_element*(env: napi_env, obj: napi_value, index: uint32, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_element*(env: napi_env, obj: napi_value, index: uint32, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}

proc napi_delete_element*(env: napi_env, obj: napi_value, index: uint32, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}

proc napi_define_properties*(env: napi_env, obj: napi_value, property_count: csize_t,
    properties: ptr NapiPropertyDescriptor): NapiStatus {.header: "<node_api.h>".}


# Methods to work with Arrays
proc napi_is_array*(env: napi_env, value: napi_value, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}

proc napi_get_array_length*(env: napi_env, value: napi_value, result: ptr uint32):
    NapiStatus {.header: "<node_api.h>".}


# Methods to compare values
proc napi_strict_equals*(env: napi_env, lhs: napi_value, rhs: napi_value, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}


# Methods to work with Functions
proc napi_call_function*(env: napi_env, recv: napi_value, fn: napi_value, argc: csize_t,
    argv: ptr napi_value, result: ptr napi_value): NapiStatus {.header: "<node_api.h>".}

proc napi_new_instance*(env: napi_env, constructor: napi_value, argc: csize_t,
    argv: ptr napi_value, result: ptr napi_value): NapiStatus {.header: "<node_api.h>".}

proc napi_instanceof*(env: napi_env, obj: napi_value, constructor: napi_value, result: ptr bool):
    NapiStatus {.header: "<node_api.h>".}


# Methods to work with napi_callbacks

# Gets all callback info in a single call. (Ugly, but faster.)
proc napi_get_cb_info*(
    env: napi_env,
    cbinfo: napi_callback_info,
    argc: ptr csize_t,
    argv: ptr UncheckedArray[napi_value],
    this_arg: napi_value,
    data: ptr pointer): NapiStatus {.header:"<node_api.h>".}

proc napi_get_new_target*(env: napi_env, cbinfo: napi_callback_info, result: ptr napi_value):
    NapiStatus {.header:"<node_api.h>".}

proc napi_define_class*(
    env: napi_env,
    utf8name: cstring,
    length: csize_t,
    constructor: napi_callback,
    data: pointer,
    property_count: csize_t,
    properties: ptr NapiPropertyDescriptor,
    result: ptr napi_value): NapiStatus {.header:"<node_api.h>".}


# Methods to work with external data objects
proc napi_wrap*(
    env: napi_env,
    js_object: napi_value,
    native_object: pointer,
    finalize_cb: napi_finalize,
    finalize_hint: pointer,
    result: ptr napi_ref): NapiStatus {.header:"<node_api.h>".}

proc napi_unrwap*(env: napi_env, js_object: napi_value, result: ptr pointer): NapiStatus {.header:"<node_api.h>".}

proc napi_remove_wrap*(env: napi_env, js_object: napi_value, result: ptr pointer): NapiStatus {.header:"<node_api.h>".}

proc napi_create_external*(
    env: napi_env,
    data: pointer,
    finalize_cb: napi_finalize,
    finalize_hint: pointer,
    result: ptr napi_value): NapiStatus {.header:"<node_api.h>".}

proc napi_get_value_external*(env: napi_env, value: napi_value, result: ptr pointer): NapiStatus {.header:"<node_api.h>".}

# TODO: Add "Methods to control object lifespan"


# Methods to support error handling
proc napi_throw*(env: napi_env, error: napi_value): NapiStatus {.header: "<node_api.h>".}

proc napi_throw_error*(env: napi_env, code: cstring, msg: cstring): NapiStatus {.header: "<node_api.h>".}

proc napi_throw_type_error*(env: napi_env, code: cstring, msg: cstring): NapiStatus {.header: "<node_api.h>".}

proc napi_throw_range_error*(env: napi_env, code: cstring, msg: cstring): NapiStatus {.header: "<node_api.h>".}

proc napi_is_error*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus {.header: "<node_api.h>".}



# Methods to support catching exceptions
proc napi_is_exception_pending*(env: napi_env, result: ptr bool): NapiStatus {.header: "<node_api.h>".}

proc napi_get_and_clear_last_exception*(env: napi_env, result: ptr napi_value): NapiStatus {.header: "<node_api.h>".}



# Methods to work with array buffers and typed arrays
proc napi_is_arraybuffer*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus {.header: "<node_api.h>".}

proc napi_create_arraybuffer*(
    env: napi_env, 
    byte_length: csize_t,
    data: ptr pointer,
    result: ptr napi_value): NapiStatus {.header: "<node_api.h>".}

proc napi_create_external_arraybuffer*(
    env: napi_env,
    external_data: pointer,
    byte_length: csize_t,
    finalize_cb: napi_finalize,
    finalize_hint: pointer,
    result: ptr napi_value): NapiStatus {.header: "<node_api.h>".}

proc napi_get_arraybuffer_info*(
    env: napi_env, 
    arraybuffer: napi_value,
    data: ptr pointer,
    byte_length: ptr csize_t): NapiStatus {.header: "<node_api.h>".}

proc napi_is_typedarray*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus {.header: "<node_api.h>".}

proc napi_create_typedarray*(
    env: napi_env,
    array_type: NApiTypedArrayType,
    length: csize_t,
    arraybuffer: napi_value,
    byte_offset: csize_t,
    result: ptr napi_value): NapiStatus {.header: "<node_api.h>".}

proc napi_get_typedarray_info*(
    env: napi_env,
    typedarray: napi_value,
    array_type: ptr NApiTypedArrayType,
    length: ptr csize_t,
    data: ptr pointer,
    arraybuffer: ptr napi_value,
    byte_offset: csize_t): NapiStatus {.header: "<node_api.h>".}

proc napi_create_dataview*(
    env: napi_env,
    length: csize_t,
    arraybuffer: napi_value,
    byte_offset: csize_t,
    result: ptr napi_value): NapiStatus {.header: "<node_api.h>".}

proc napi_is_dataview*(env: napi_env, value: napi_value, result: ptr bool): NapiStatus {.header: "<node_api.h>".}

proc napi_get_dataview_info*(
    env: napi_env,
    dataview: napi_value,
    byte_length: ptr csize_t,
    data: ptr pointer,
    arraybuffer: ptr napi_value,
    byte_offset: ptr csize_t): NapiStatus {.header: "<node_api.h>".}



# Version management
proc napi_get_version*(env: napi_env, result: ptr uint32): NapiStatus {.header: "<node_api.h>".}



# Promises
proc napi_create_promise*(env: napi_env, deffered: ptr napi_deferred, promise: ptr napi_value): NapiStatus {.header: "<node_api.h>".}
proc napi_resolve_deferred*(env: napi_env, deffered: napi_deferred, resolution: napi_value):
    NapiStatus {.header: "<node_api.h>".}
proc napi_reject_deferred*(env: napi_env, deffered: napi_deferred, rejection: napi_value):
    NapiStatus {.header: "<node_api.h>".}
proc napi_is_promise*(env: napi_env, promise: napi_value, is_promise: ptr bool):
    NapiStatus {.header: "<node_api.h>".}
# Running a script
proc napi_run_script*(env: napi_env, script: napi_value, result: ptr napi_value):
    NapiStatus {.header: "<node_api.h>".}
# Memory management
proc napi_adjust_external_memory*(env: napi_env, change_in_bytes: int64, adjusted_value: ptr int64):
    NapiStatus {.header: "<node_api.h>".}

# Dates
proc napi_create_date*(env: napi_env, time: float64, result: ptr napi_value): NapiStatus {.header: "<node_api.h>".}

proc napi_is_date*(env: napi_env, value: napi_value, is_date: ptr bool): NapiStatus {.header: "<node_api.h>".}

proc napi_get_date_value*(env: napi_env, value: napi_value, result: ptr float64): NapiStatus {.header: "<node_api.h>".}

proc napi_add_finalizer*(
    env: napi_env,
    js_object: napi_value,
    native_object: pointer,
    finalize_cb: napi_finalize,
    finalize_hint: pointer,
    result: ptr napi_ref): NapiStatus {.header: "<node_api.h>".}



# TODO Add experimental features?
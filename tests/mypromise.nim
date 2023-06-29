import denim
import std/os

var jsData: int
var promiseData: ref PromiseData[pointer]

when defined highlevelapi:
  # Promises - High-Level API
  discard # todo
else:
  # Promises - Low-level API
  # https://nodejs.org/api/n-api.html#promises
  proc onExec(env: napi_env, data: pointer) {.cdecl.} =
    # Where you can execute heavy stuff
    var data = cast[ptr ptr[PromiseData[ptr int]]](data)
    if data[].jsData[] <= 5:
      data[].status = asyncActionFail

  proc onComplete(env: napi_env, status: NapiStatus, data: pointer) {.cdecl.} =
    # A callback function to call when execution completed
    var d = cast[ptr ptr[PromiseData[ptr int]]](data)
    if d[].status == asyncActionSuccess:
      assert env.napi_resolve_deferred(d[].deferred, %*(d[].jsData[] * 10))
    else:
      assert env.napi_reject_deferred(d[].deferred, %*("Expected a number > 5. Got: " & $(d[].jsData[])))
    assert env.napi_delete_async_work(d[].work)

  init proc(module: Module) =
    proc testPromise(x: int) {.export_napi.} =
      var
        promise: napi_value
        status: NapiStatus
      
      jsData = args[0].getInt
      promiseData = newPromiseData[pointer](jsData.addr)
      assert env.napi_create_promise(promiseData.deferred.addr, promise.addr)
      assert env.napi_create_async_work(nil, %* "MyAsyncWork", onExec, onComplete, promiseData.addr, promiseData.work.addr)
      assert env.napi_queue_async_work(promiseData.work)

      return promise
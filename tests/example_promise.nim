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
    let d = cast[ptr PromiseData[ptr int]](data)
    if d.isNil or d[].jsData.isNil:
      return
    if d[].jsData[] <= 5:
      d[].status = asyncActionFail

  proc onComplete(env: napi_env, status: NapiStatus, data: pointer) {.cdecl.} =
    let d = cast[ptr PromiseData[ptr int]](data)
    if d.isNil:
      return

    if d[].status == asyncActionSuccess:
      assert env.napi_resolve_deferred(d[].deferred, %*(d[].jsData[] * 10))
    else:
      assert env.napi_reject_deferred(
        d[].deferred,
        %*("Expected a number > 5. Got: " & $(d[].jsData[]))
      )

    assert env.napi_delete_async_work(d[].work)

    if not d[].jsData.isNil:
      deallocShared(d[].jsData)
    deallocShared(d)

  init proc(module: Module) =
    proc testPromise(x: int) {.export_napi.} =
      var promise: napi_value

      # Heap-allocate input so it survives until async callbacks complete.
      let pData = cast[ptr PromiseData[ptr int]](allocShared0(sizeof(PromiseData[ptr int])))
      let pInt  = cast[ptr int](allocShared0(sizeof(int)))

      pInt[] = args[0].getInt
      pData[].jsData = pInt
      pData[].status = asyncActionSuccess

      assert env.napi_create_promise(pData[].deferred.addr, promise.addr)
      assert env.napi_create_async_work(
        nil,
        %* "MyAsyncWork",
        onExec,
        onComplete,
        cast[pointer](pData),
        pData[].work.addr
      )
      assert env.napi_queue_async_work(pData[].work)

      return promise
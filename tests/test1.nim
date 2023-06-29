import std/[unittest, strutils, osproc]

when not defined skipbuild:
  var addons = ["myaddon", "myobject"]
  test "can build addons with node-gyp":
    for addonName in addons:
      let status = execCmdEx("denim build ./tests/" & addonName & ".nim --yes")
      echo "[OK] " & addonName & ".nim"
      assert status.exitCode == 0

  test "can build addons with CMake":
    for addonName in addons:
      let status = execCmdEx("denim build ./tests/" & addonName & ".nim --cmake --yes")
      echo "[OK] " & addonName & ".nim"
      assert status.exitCode == 0

test "can run myaddon (NodeJS)":
  let status = execCmdEx("node tests/js/myaddon.js")
  let hello = status.output.strip()
  echo hello
  assert hello == "Hello, World! from Nim. This is awesome!"
  assert status.exitCode == 0

test "can run mypromise (NodeJS)":
  let status = execCmdEx("node tests/js/mypromise.js")
  echo status.output.strip()
  assert status.exitCode == 0

test "can run myobject (NodeJS)":
  let status = execCmdEx("node tests/js/myobject.js")
  echo status.output.strip()
  assert status.exitCode == 0
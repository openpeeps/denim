import std/[unittest, strutils, osproc, os]

when not defined skipbuild:
  var addons = ["myaddon", "myobject", "mypromise", "myexceptions"]
  # test "can build addons with node-gyp":
  #   for addonName in addons:
  #     let status = execCmdEx("denim build tests" / addonName & ".nim -y")
  #     if status.exitCode != 0:
  #       echo status.output
  #     else:
  #       echo "[OK] " & addonName & ".nim"
  #     assert status.exitCode == 0

  test "can build addons with CMake":
    for addonName in addons:
      let status = execCmdEx("denim build tests" / addonName & ".nim --cmake -y")
      if status.exitCode != 0:
        echo status.output
      else:
        echo "[OK] " & addonName & ".nim"
      assert status.exitCode == 0

test "can run myaddon (NodeJS)":
  let status = execCmdEx("node " & "tests" / "js" / "myaddon.js")
  let hello = status.output.strip()
  echo hello
  assert hello == "Hello, World! from Nim. This is awesome!"
  assert status.exitCode == 0

test "can run mypromise (NodeJS)":
  let status = execCmdEx("node " & "tests" / "js" / "mypromise.js")
  echo status.output.strip()
  assert status.exitCode == 0

test "can run myobject (NodeJS)":
  let status = execCmdEx("node " & "tests" / "js" / "myobject.js")
  echo status.output.strip()
  assert status.exitCode == 0

test "can run myexceptions (NodeJS)":
  let status = execCmdEx("node " & "tests" / "js" / "myexceptions.js")
  assert status.exitCode == 1

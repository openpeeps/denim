import std/[unittest, strutils, osproc]

test "can build addon with node-gyp":
  let status = execCmdEx("denim build ./tests/myaddon.nim --yes")
  assert status.exitCode == 0

test "can build addon with CMake.js":
  let status = execCmdEx("denim build ./tests/myaddon.nim --cmake --yes")
  echo status.output
  assert status.exitCode == 0

test "can run addon (node)":
  let status = execCmdEx("node tests/myaddon.js")
  let hello = status.output.strip()
  echo hello
  assert hello == "Hello, World!"
  assert status.exitCode == 0
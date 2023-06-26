import std/[unittest, strutils, osproc]

test "can build addon":
  let status = execCmdEx("denim build ./tests/myaddon.nim -y")
  echo status.output
  assert status.exitCode == 0

test "can run addon (node)":
  let status = execCmdEx("node tests/myaddon.js")
  let hello = status.output.strip()
  echo hello
  assert hello == "Hello, World!"
  assert status.exitCode == 0
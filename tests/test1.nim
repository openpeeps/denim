import std/[unittest, strutils, osproc, os]

when not defined skipbuild:
  var addons = ["addon", "object", "promise", "exception", "class"]
  # test "can build addons with node-gyp":
  #   for addonName in addons:
  #     let status = execCmdEx("denim build tests" / addonName & ".nim -y")
  #     if status.exitCode != 0:
  #       echo status.output
  #     else:
  #       echo "[OK] " & addonName & ".nim"
  #     check status.exitCode == 0

  test "can build addons with CMake":
    var denimBin =
      when defined(windows):
        "denim.exe"
      else:
        "denim"

    let localDenim = "bin" / denimBin
    denimBin =
      if fileExists(localDenim): localDenim
      else: getHomeDir() / ".nimble" / "bin" / denimBin

    for addonName in addons:
      let addonFile = "tests" / ("example_" & addonName & ".nim")
      let cmd = quoteShell(denimBin) & " build " & quoteShell(addonFile) & " --cmake -y"
      let status = execCmdEx(
        cmd,
        options = {poStdErrToStdOut, poUsePath, poEvalCommand}
      )

      if status.exitCode != 0:
        echo status.output
        fail() # keep current behavior
      else:
        echo("[OK] Built " & addonName & ".nim with CMake")
      check status.exitCode == 0


test "can run example_addon (NodeJS)":
  let status = execCmdEx("node " & "tests" / "js" / "example_addon.js")
  let hello = status.output.strip()
  echo hello
  check hello == "Hello, World! from Nim. This is awesome!"
  check status.exitCode == 0

test "can run example_promise (NodeJS)":
  let status = execCmdEx("node " & "tests" / "js" / "example_promise.js")
  echo status.output.strip()
  check status.exitCode == 0

test "can run example_object (NodeJS)":
  let status = execCmdEx("node " & "tests" / "js" / "example_object.js")
  echo status.output.strip()
  check status.exitCode == 0

test "can run example_exception (NodeJS)":
  let status = execCmdEx("node " & "tests" / "js" / "example_exception.js")
  check status.exitCode == 1

test "can run example_class (NodeJS)":
  let status = execCmdEx("node " & "tests" / "js" / "example_class.js")
  check status.output.strip() == "Hello from User.hello()"
  check status.exitCode == 0
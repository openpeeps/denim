import std/[unittest, os]
import denim/commands/build

# Unit tests for denim's dependency --path resolution.
# Only pure procs (no clue/nimble subprocesses) so these run
# deterministically anywhere.

proc fixtureDir(name: string): string =
  result = getTempDir() / ("denim-test-" & name)
  if dirExists(result):
    removeDir(result)
  createDir(result)

suite "dep resolution - parseNimbleRequires":
  test "names, constraints, nim skip and URLs":
    let dir = fixtureDir("requires")
    writeFile(dir / "foo.nimble", """
version = "0.1.0"
requires "nim >= 2.2.0"
requires "vancode >= 0.2.14"
requires "justaname"
feature "extra":
  requires "https://github.com/dfkup/stdlib"
""")
    check parseNimbleRequires(dir / "foo.nimble") ==
      @["vancode", "justaname", "https://github.com/dfkup/stdlib"]

  test "missing file yields no requires":
    check parseNimbleRequires(getTempDir() / "denim-no-such.nimble") ==
      newSeq[string]()

suite "dep resolution - nimbleSrcDir":
  test "explicit srcDir and default":
    let dir = fixtureDir("srcdir")
    writeFile(dir / "a.nimble", "srcDir = \"source\"\n")
    writeFile(dir / "b.nimble", "version = \"1.0\"\n")
    check nimbleSrcDir(dir / "a.nimble") == "source"
    check nimbleSrcDir(dir / "b.nimble") == "src"

suite "dep resolution - findProjectNimble":
  test "nearest .nimble walking up":
    let dir = fixtureDir("proj")
    createDir(dir / "sub" / "deep")
    writeFile(dir / "root.nimble", "version = \"1.0\"\n")
    writeFile(dir / "sub" / "inner.nimble", "version = \"1.0\"\n")
    check findProjectNimble(dir / "sub" / "deep") == dir / "sub" / "inner.nimble"
    check findProjectNimble(dir / "nonexistent") == dir / "root.nimble"

suite "dep resolution - packageImportDir":
  test "src layout, flat layout and missing root":
    let dir = fixtureDir("layout")
    createDir(dir / "withsrc" / "src" / "withsrc")
    writeFile(dir / "withsrc" / "withsrc.nimble", "srcDir = \"src\"\n")
    createDir(dir / "flat")
    writeFile(dir / "flat" / "flat.nimble", "version = \"1.0\"\n")
    check packageImportDir(dir / "withsrc", "withsrc") == dir / "withsrc" / "src"
    check packageImportDir(dir / "flat", "flat") == dir / "flat"
    check packageImportDir(dir / "gone", "gone") == ""

suite "dep resolution - cmpPkgVersion":
  test "HEAD sorts above everything, numeric per part":
    check cmpPkgVersion("HEAD", "9.9.9") > 0
    check cmpPkgVersion("0.2.10", "0.2.9") > 0
    check cmpPkgVersion("0.2.4", "0.2.11") < 0
    check cmpPkgVersion("1.0", "1.0") == 0

suite "dep resolution - urlLastSegment":
  test "repo name, slashes and .git suffix":
    check urlLastSegment("https://github.com/dfkup/stdkups") == "stdkups"
    check urlLastSegment("https://github.com/dfkup/stdlib/") == "stdlib"
    check urlLastSegment("https://github.com/foo/bar.git") == "bar"
    check urlLastSegment("plainname") == "plainname"

suite "dep resolution - unresolvable packages":
  test "unknown names yield empty dirs, no crash":
    check clueDevelopDir("denim-no-such-pkg-xyz") == ""
    check nimblePackageDir("denim-no-such-pkg-xyz") == ""
    let r = resolveOnePackage("denim-no-such-pkg-xyz", @[], true)
    check r.root == "" and r.dir == ""

import os, strutils, macros
from clymene/util import cmd

macro `?`* (a: bool, body: untyped): untyped =
    # Create a macro for a short hand conditional
    # value == expected ? "do something" ! "not yet"
    # https://nim-lang.org/docs/sugar.html
    let x = body[1]
    let y = body[2]
    result = quote:
        if `a`: `x` else: `y`

proc printf*(formatstr: cstring) {.importc: "printf", varargs, header: "<stdio.h>".}

proc getNimPath*(knownPath: string = ""): string =
    # Determine absolute path to Nim by executing "which nim"
    # On MacOS, the result of "which nim" will return /usr/local/bin/nim
    # which points to another symlink under Cellar directory
    var slink = cmd("which", ["nim"]).strip()
    # expand the path of the symlink
    var exSlink = os.expandSymlink(slink)
    # rm the symbolink name "nim" from path
    slink = slink.replace("nim", "")
    # normalize the symlink and get the absolute path of the main symlink
    # right now, we can simply normalize the path and get directly into
    # nim's "lib" source directory.
    return os.normalizedPath(os.normalizedPath(slink & exSlink).replace("bin", "") & "/../nim/lib")

proc getPath*(currentPath:string, toDirName:string, relative:string=""): string = 
    # Return path based on given current directory 
    return os.joinPath(currentPath, relative, toDirName)
import os
import strutils
from clymene/util import cmd

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
    return os.normalizedPath(os.normalizedPath(slink & exSlink).replace("nim", "") & "/../nim/lib")

proc getPath*(currentPath:string, toDirName:string, relative:string=""): string = 
    # Return path based on given current directory 
    return os.joinPath(currentPath, relative, toDirName)
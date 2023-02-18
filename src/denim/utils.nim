import std/[os, sequtils]

proc getNimPath*(knownPath: string = ""): string =
  # Retrieve the path of the NIM library.
  return "/Users/cristiangeorge/.choosenim/toolchains/nim-1.6.0/lib"

proc getPath*(currentPath:string, toDirName:string, relative:string=""): string = 
  # Return path based on given current directory 
  return os.joinPath(currentPath, relative, toDirName)

proc isEmptyDir*(dir: string): bool =
  toSeq(walkdir dir).len == 0
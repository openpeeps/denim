import std/[os, sequtils]

proc getPath*(currentPath:string, toDirName:string, relative:string=""): string = 
  # Return path based on given current directory 
  return os.joinPath(currentPath, relative, toDirName)

proc isEmptyDir*(dir: string): bool =
  toSeq(walkdir dir).len == 0
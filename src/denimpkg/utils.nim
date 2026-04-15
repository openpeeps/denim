# Node-API (N-API) bindings for Nim.
#
# Originally written by Andrew Breidenbach, later modified by Andrei Rosca
# and now fully implemented in Nim and maintained by OpenPeeps.
# 
#     https://github.com/AjBreidenbach
#     https://github.com/andi23rosca
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/denim

import std/[os, sequtils]

proc getPath*(currentPath:string, toDirName:string, relative:string=""): string = 
  # Return path based on given current directory 
  return os.joinPath(currentPath, relative, toDirName)

proc isEmptyDir*(dir: string): bool =
  toSeq(walkdir dir).len == 0
from os import joinPath

# macro `?`* (a: bool, body: untyped): untyped =
#     # Create a macro for a short hand conditional
#     # value == expected ? "do something" ! "not yet"
#     # https://nim-lang.org/docs/sugar.html
#     let x = body[1]
#     let y = body[2]
#     result = quote:
#         if `a`: `x` else: `y`

proc getNimPath*(knownPath: string = ""): string =
    # Retrieve the path of the NIM library.
    return "/Users/cristiangeorge/.choosenim/toolchains/nim-1.6.0/lib"

proc getPath*(currentPath:string, toDirName:string, relative:string=""): string = 
    # Return path based on given current directory 
    return os.joinPath(currentPath, relative, toDirName)
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

iterator enumerate*[T](open: openarray[T]): (int, T) =
  var ct = 0
  for elem in open:
    yield (ct, elem)
    inc ct

proc toUnchecked*[T](open: openarray[T]): ptr UncheckedArray[T] =
  result = cast[ptr UncheckedArray[T]](alloc(sizeof(T) * open.len))
  for i, elem in open.enumerate:
    result[][i] = elem

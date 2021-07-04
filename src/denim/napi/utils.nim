iterator enumerate*[T](open: openarray[T]): (int, T) =
  var ct = 0
  for elem in open:
    yield (ct, elem)
    inc ct

proc toUnchecked*[T](open: openarray[T]): ptr UncheckedArray[T] =
  result = cast[ptr UncheckedArray[T]](alloc(sizeof(T) * open.len))
  for i, elem in open.enumerate:
    result[][i] = elem



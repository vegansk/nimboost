## Low level memory primitives

proc findInMem*(buf: pointer, size: int, what: pointer, wSize: int): tuple[pos: int, length: int] =
  ## Finds ``what`` of size ``wSize`` in ``buf`` of ``size`` and returns the ``position``
  ## of match. If ``buf``'s tail contains only the part of ``what``, then ``length`` will
  ## contain the actual size of matched data.
  let buff = cast[cstring](buf)
  let sBuff = cast[cstring](what)
  var i = 0
  var si = 0
  while i < size and si < wSize:
    if buff[i] == sBuff[si]:
      inc si
    elif si != 0:
      i -= si - 1
      si = 0
    inc i
  if si == 0:
    result.pos = -1
  else:
    result.pos = i - si
    result.length = si


## Module contains `type` to string formatters for some `types`.

import strutils

proc mkDigit(v: int, lowerCase: bool): string {.inline.} =
  doAssert(v < 26)
  if v < 10:
    result = $chr(ord('0') + v)
  else:
    result = $chr(ord(if lowerCase: 'a' else: 'A') + v - 10)

proc intToStr*(n: SomeNumber, radix = 10, len = 0, fill = ' ', lowerCase = false): string =
  ## Converts ``n`` to string. If ``n`` is `SomeReal`, it casts to `int64`.
  ## Conversion is done using ``radix``. If result's length is lesser then
  ## ``len``, it aligns result to the right with ``fill`` char.
  ## If ``len`` is negative, the result is aligned to the left.
  ## If `lowerCase` is true, formatted string will be in the lower case.
  when n is SomeUnsignedInt:
    var v = n.uint64
    let s = false
  else:
    var v = n.int64
    let s = v.int64 < 0
    if s:
      v = v * -1

  if v == 0:
    result = "0"
  else:
    result = ""
    while v > (type(v))0:
      let d = v mod (type(v))radix
      v = v div (type(v))radix
      result.add(mkDigit(d.int, lowerCase))
    for idx in 0..<(result.len div 2):
      swap result[idx], result[result.len - idx - 1]
  var length = abs(len)
  if length == 0 or (s and (result.len >= length - 1)) or (not s and (result.len >= length)):
    if s:
      result = "-" & result
  elif len < 0:
    if s:
      result = "-" & result
    for i in result.len..<length:
      result.add(fill)
  else:
    if fill != '0':
      # The sign must be near the number
      if s:
        result = "-" & result
    var toFill = length - result.len
    var prefix = newString(toFill)
    for idx in 0..<toFill:
      prefix[idx] = fill
    if fill == '0' and s:
      prefix[0] = '-'
    result = prefix & result

proc alignStr*(s: string, len: int, fill = ' ', trunc = false): string =
  ## Aligns ``s`` using ``fill`` char to the right if ``len`` is
  ## positive, or to the left, if ``len`` is negative.
  ## If the length of ``s`` is bigger then `abs(len)` and ``trunc`` == true,
  ## truncates ``s``
  let absLen = abs(len)
  if len == 0 or s.len == absLen:
    result = s
  elif s.len > absLen:
    if not trunc:
      result = s
    elif len > 0:
      result = s[0 ..< absLen]
    else:
      result = s[(s.len-absLen) ..< s.len]
  else:
    result = newString(absLen)
    var idx = 0
    if len > 0:
      while idx < absLen - s.len:
        result[idx] = fill
        inc idx
    result[idx..(idx + s.len - 1)] = s
    if len < 0:
      idx += s.len
      while idx < absLen:
        result[idx] = fill
        inc idx

proc floatToStr*(v: SomeNumber, len = 0, prec = 0, sep = '.', fill = ' ',  scientific = false): string =
  ## Converts ``v`` to string with precision == ``prec``. If result's length
  ## is lesser then ``len``, it aligns result to the right with ``fill`` char.
  ## If ``len`` is negative, the result is aligned to the left.
  let f = if scientific: ffScientific else: if prec == 0: ffDefault else: ffDecimal
  if len > 0 and v < 0 and fill == '0':
    result = "-" & alignStr(formatBiggestFloat(-v.BiggestFloat, f, prec, sep), len-1, fill)
  else:
    result = alignStr(formatBiggestFloat(v.BiggestFloat, f, prec, sep), len, fill)


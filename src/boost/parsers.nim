## Miscellaneous parse tools

import limits, strutils

{.push overflowChecks: off.}

proc strToUInt64*(s: string, radix = 10): uint64 {.raises: ValueError.} =
  let d = s.strip
  result = 0
  var prev = result
  var i = 0
  var dl = d.len
  if dl > 0 and s[i] == '+':
    inc i
  for i in i..<dl:
    if d[i] in {'0'..'9'} or d[i] in {'a'..'z'} or d[i] in {'A'..'Z'}:
      let n = if d[i] in {'0'..'9'}:
                ord(d[i]) - ord('0')
              elif d[i] in {'a'..'z'}:
                ord(d[i]) - ord('a') + 10
              else:
                ord(d[i]) - ord('A') + 10
      if n >= radix:
        raise newException(ValueError, "Parse error: " & d & " bad format, radix = " & $radix)
      prev = result
      result = result * radix.uint64 + n.uint64
      if prev > result:
        raise newException(ValueError, "Overflow: " & d & " can't fit into uint64")
    elif d[i] == '_':
      continue
    else:
      raise newException(ValueError, "Parse error: " & d & " bad format")

proc strToUInt*(s: string, radix = 10): uint {.raises: ValueError.} =
  let res = strToUInt64(s, radix)
  when sizeof(uint) != 8:
    if res > uint.max.uint64:
      raise newException(ValueError, "Overflow: " & s & " can't fit into uint")
  result = res.uint

proc strToUInt32*(s: string, radix = 10): uint32 {.raises: ValueError.} =
  let res = strToUInt64(s, radix)
  if res > uint32.max.uint64:
    raise newException(ValueError, "Overflow: " & s & " can't fit into uint")
  result = res.uint32

proc strToUInt16*(s: string, radix = 10): uint16 {.raises: ValueError.} =
  let res = strToUInt64(s, radix)
  if res > uint16.max.uint64:
    raise newException(ValueError, "Overflow: " & s & " can't fit into uint")
  result = res.uint16

proc strToUInt8*(s: string, radix = 10): uint8 {.raises: ValueError.} =
  let res = strToUInt64(s, radix)
  if res > uint8.max.uint64:
    raise newException(ValueError, "Overflow: " & s & " can't fit into uint")
  result = res.uint8

proc strToInt64*(s: string, radix = 10): int64 {.raises: ValueError.} =
  let d = s.strip
  var negate = false
  if d[0] == '-':
    negate = true
  result = strToUInt64(if negate: d[1..^1] else: d, radix).int64 * (if negate: -1'i64 else: 1'i64)
  if negate and result > 0 or (not negate) and result < 0:
    raise newException(ValueError, "Overflow: " & s & " can't fit into int64")

proc strToInt*(s: string, radix = 10): int {.raises: ValueError.} =
  let res = strToInt64(s, radix)
  when sizeof(int) != 8:
    if res < int.min.int64 or res > int.max.int64:
      raise newException(ValueError, "Overflow: " & s & " can't fit into uint")
  result = res.int

proc strToInt32*(s: string, radix = 10): int32 {.raises: ValueError.} =
  let res = strToInt64(s, radix)
  if res < int32.min.int64 or res > int32.max.int64:
    raise newException(ValueError, "Overflow: " & s & " can't fit into uint")
  result = res.int32

proc strToInt16*(s: string, radix = 10): int16 {.raises: ValueError.} =
  let res = strToInt64(s, radix)
  if res < int16.min.int64 or res > int16.max.int64:
    raise newException(ValueError, "Overflow: " & s & " can't fit into uint")
  result = res.int16

proc strToInt8*(s: string, radix = 10): int8 {.raises: ValueError.} =
  let res = strToInt64(s, radix)
  if res < int8.min.int64 or res > int8.max.int64:
    raise newException(ValueError, "Overflow: " & s & " can't fit into uint")
  result = res.int8

{.pop.}

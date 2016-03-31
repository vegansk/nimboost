## Miscellaneous parse tools

import limits, strutils

proc strToInt64*(s: string): int64 {.raises: ValueError.} =
  strutils.parseBiggestInt(s.strip)

proc strToInt*(s: string): int {.raises: ValueError.} =
  let res = strToInt64(s)
  when sizeof(int) != 8:
    if res < int.min.int64 or res > int.max.int64:
      raise newException(ValueError, "Overflow: " & $res & " cant fit into int")
  result = res.int

proc strToInt32*(s: string): int32 {.raises: ValueError.} =
  let res = strToInt64(s)
  if res < int32.min.int64 or res > int32.max.int64:
     raise newException(ValueError, "Overflow: " & $res & " cant fit into int32")
  result = res.int32

proc strToInt16*(s: string): int16 {.raises: ValueError.} =
  let res = strToInt64(s)
  if res < int16.min.int64 or res > int16.max.int64:
     raise newException(ValueError, "Overflow: " & $res & " cant fit into int16")
  result = res.int16

proc strToInt8*(s: string): int8 {.raises: ValueError.} =
  let res = strToInt64(s)
  if res < int8.min.int64 or res > int8.max.int64:
     raise newException(ValueError, "Overflow: " & $res & " cant fit into int8")
  result = res.int8

proc strToUInt64*(s: string): uint64 {.raises: ValueError.} =
  let d = s.strip
  result = 0
  var prev = 0'u64
  var i = 0
  var dl = d.len
  if dl > 0 and s[i] == '+':
    inc i
  for i in i..<dl:
    if d[i] in {'0'..'9'}:
      prev = result
      result = result * 10 + (ord(d[i]) - ord('0')).uint64
      if prev > result:
        raise newException(ValueError, "Overflow: " & d & " cant fit into uint64")
    elif d[i] == '_':
      continue
    else:
      raise newException(ValueError, "Parse error: " & d & " cant fit into uint64")
        
proc strToUInt*(s: string): uint {.raises: ValueError.} =
  let res = strToUInt64(s)
  when sizeof(uint) != 8:
    if res > uint.max.uint64:
      raise newException(ValueError, "Overflow: " & $res & " cant fit into uint")
  result = res.uint

proc strToUInt32*(s: string): uint32 {.raises: ValueError.} =
  let res = strToUInt64(s)
  if res > uint32.max.uint64:
    raise newException(ValueError, "Overflow: " & $res & " cant fit into uint32")
  result = res.uint32

proc strToUInt16*(s: string): uint16 {.raises: ValueError.} =
  let res = strToUInt64(s)
  if res > uint16.max.uint64:
    raise newException(ValueError, "Overflow: " & $res & " cant fit into uint16")
  result = res.uint16

proc strToUInt8*(s: string): uint8 {.raises: ValueError.} =
  let res = strToUInt64(s)
  if res > uint8.max.uint64:
    raise newException(ValueError, "Overflow: " & $res & " cant fit into uint8")
  result = res.uint8


## Miscellaneous parse tools

import limits
from strutils import nil

proc strToInt64*(s: string): int64 {.raises: ValueError.} =
  strutils.parseBiggestInt(s)

proc strToInt*(s: string): int {.raises: ValueError.} =
  let res = strToInt64(s)
  when sizeof(int) != 8:
    if res < int.min or res > int.max:
      raise newException(ValueError, "Overflow: " & $res & " can't be int")
  result = res.int

proc strToInt32*(s: string): int32 {.raises: ValueError.} =
  let res = strToInt64(s)
  if res < int32.min or res > int32.max:
     raise newException(ValueError, "Overflow: " & $res & " can't be int32")
  result = res.int32

proc strToInt16*(s: string): int16 {.raises: ValueError.} =
  let res = strToInt64(s)
  if res < int16.min or res > int16.max:
     raise newException(ValueError, "Overflow: " & $res & " can't be int16")
  result = res.int16

proc strToInt8*(s: string): int8 {.raises: ValueError.} =
  let res = strToInt64(s)
  if res < int8.min or res > int8.max:
     raise newException(ValueError, "Overflow: " & $res & " can't be int8")
  result = res.int8

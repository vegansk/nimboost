import unittest, boost/limits, typetraits

# Workaround for https://github.com/nim-lang/Nim/issues/4714
when defined(js):
  proc `$`(x: uint): string =
    x.int64.`$`

template testLimit(t: typedesc): untyped =
  echo "Limits for ", t.name, " is [", t.min, "..", t.max, "]"

suite "Limits":
  test "Output limits":
    int8.testLimit
    int16.testLimit
    int32.testLimit
    int64.testLimit
    int.testLimit

    uint8.testLimit
    uint16.testLimit
    uint32.testLimit
    when not defined(js):
      uint64.testLimit
    uint.testLimit

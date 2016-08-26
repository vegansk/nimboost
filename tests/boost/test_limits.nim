import unittest, boost.limits, typetraits

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
    uint64.testLimit
    uint.testLimit

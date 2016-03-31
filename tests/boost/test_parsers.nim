import unittest, boost.parsers, boost.limits

template checkInt(typ: untyped, fun: untyped): untyped =
  check: fun($typ.min) == typ.min
  check: fun($typ.max) == typ.max
  expect(ValueError): discard fun("ZERO")
  when sizeof(typ) != 8:
    expect(ValueError): discard fun($int64.min)
    expect(ValueError): discard fun($int64.max)

suite "Parsers":
  test "Parsers - ordinal types from string":
    int64.checkInt(strToInt64)
    int.checkInt(strToInt)
    int32.checkInt(strToInt32)
    int16.checkInt(strToInt16)
    int8.checkInt(strToInt8)

import unittest, boost.parsers, boost.limits

template checkInt(typ: untyped, fun: untyped): untyped =
  check: fun($typ.min) == typ.min
  check: fun($(typ.min + 13)) == typ.min + 13
  check: fun($typ.max) == typ.max
  check: fun($(typ.max - 77)) == typ.max - 77
  expect(ValueError): discard fun("ZERO")
  when sizeof(typ) != 8:
    expect(ValueError): discard fun($int64.min)
    expect(ValueError): discard fun($int64.max)

template checkUInt(typ: untyped, fun: untyped): untyped =
  check: fun($typ.min) == typ.min
  check: fun($(typ.min + 13)) == typ.min + 13
  check: fun($typ.max) == typ.max
  check: fun($(typ.max - 77)) == typ.max - 77
  expect(ValueError): discard fun("ZERO")
  when sizeof(typ) != 8:
    expect(ValueError): discard fun($int64.max)

suite "Parsers":
  test "Ordinal types from string":
    int64.checkInt(strToInt64)
    int.checkInt(strToInt)
    int32.checkInt(strToInt32)
    int16.checkInt(strToInt16)
    int8.checkInt(strToInt8)

    uint64.checkUInt(strToUInt64)
    uint.checkUInt(strToUInt)
    uint32.checkUInt(strToUInt32)
    uint16.checkUInt(strToUInt16)
    uint8.checkUInt(strToUInt8)

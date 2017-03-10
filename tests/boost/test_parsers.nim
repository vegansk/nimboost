import unittest, boost.parsers, boost.limits

template checkInt(typ: untyped, fun: untyped): untyped =
  check: fun($typ.min) == typ.min
  check: fun($(typ.min + 13)) == typ.min + 13
  check: fun($typ.max) == typ.max
  check: fun($(typ.max - 77)) == typ.max - 77
  expect(ValueError): discard fun("ZERO")
  when sizeof(typ) != 8 and not defined(js): # Bug https://github.com/nim-lang/Nim/issues/4714
    expect(ValueError): discard fun($(typ.min.int64 - 1))
    expect(ValueError): discard fun($(typ.max.int64 + 1))

template checkUInt(typ: untyped, fun: untyped): untyped =
  check: fun($typ.min) == typ.min
  check: fun($(typ.min + 13)) == typ.min + 13
  check: fun($typ.max) == typ.max
  check: fun($(typ.max - 77)) == typ.max - 77
  expect(ValueError): discard fun("ZERO")
  when sizeof(typ) != 8:
    expect(ValueError): discard fun($(typ.max.int64 + 1))

suite "Parsers":
  test "Ordinal types from string":
    when not defined(js): # Bug https://github.com/nim-lang/Nim/issues/4714
      int64.checkInt(strToInt64)
    int.checkInt(strToInt)
    int32.checkInt(strToInt32)
    int16.checkInt(strToInt16)
    int8.checkInt(strToInt8)

    when not defined(js): # Bug https://github.com/nim-lang/Nim/issues/4714
      uint64.checkUInt(strToUInt64)
      uint.checkUInt(strToUInt)
      uint32.checkUInt(strToUInt32)
      uint16.checkUInt(strToUInt16)
      uint8.checkUInt(strToUInt8)

  test "Radix":
    check: "10".strToInt(10) == 10
    check: "a".strToInt(16) == 10
    check: "A".strToInt(16) == 10
    check: "deadbeef".strToInt(16) == 0xdeadbeef

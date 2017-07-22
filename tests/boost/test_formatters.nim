import boost.formatters,
       unittest

suite "formatters":
  test "intToStr":
    # Simple cases
    check: intToStr(0) == "0"
    when not defined(js):
      check: intToStr(1'u64) == "1"
    check: intToStr(-123456) == "-123456"
    check: intToStr(123.456'f64) == "123"

    # Max length and fill char
    check: intToStr(0, len = 3, fill = '0') == "000"
    check: intToStr(-100, len = 5) == " -100"
    check: intToStr(-100, len = 5, fill = '0') == "-0100"

    # Radix
    check: intToStr(10, radix = 16) == "A"
    check: intToStr(10, radix = 2, len = 8, fill = '0') == "00001010"

    # Negative justify
    check: intToStr(123, len = -5) == "123  "
    check: intToStr(-123, len = -5, fill = '0') == "-1230"

  test "alignStr":
    check: alignStr("abc", 5, '.') == "..abc"
    check: alignStr("abc", -5, '.') == "abc.."
    check: alignStr("abc", 2, trunc=false) == "abc"
    check: alignStr("abc", -2, trunc=false) == "abc"
    check: alignStr("abc", 2, trunc=true) == "ab"
    check: alignStr("abc", -2, trunc=true) == "bc"

  test "floatToStr":
    check: floatToStr(1.0) == "1"
    check: floatToStr(10, prec = 3) == "10.000"
    check: floatToStr(-20, prec = 3, fill = '0', len = 8) == "-020.000"
    check: floatToStr(-20, prec = 3, fill = '0', len = -8) == "-20.0000"
    when defined(js):
      check: floatToStr(-20, scientific = true, prec = 3) == "-2.000e+1"
    else:
      check: floatToStr(-20, scientific = true, prec = 3) == "-2.000e+01"

import boost.richstring,
       strutils,
       boost.parsers,
       unittest

suite "richstring":
  test "string interpolation":
    # Simple cases
    check: fmt"Hello, world!" == "Hello, world!"
    let v = 1
    check: fmt"v = $v" == "v = 1"
    check: fmt"v = $$v" == "v = $v"
    let s = "string"
    check: not compiles(fmt(s))
    check: fmt"${s[0..2].toUpper}" == "STR"

    # Int formatters
    check: fmt"$v%" == "1%"
    check: fmt"$v%%" == "1%"
    check: fmt"$v%d" == "1"
    check: fmt"${-10}%04d" == "-010"
    check: fmt"${-10}%-04d" == "-100"
    check: fmt"${-10}%4d" == " -10"
    check: fmt"${-10}%-4d" == "-10 "
    check: fmt"${10}%x" == "A"
    check: fmt"0x${10}%02x" == "0x0A"

    # String formatters
    check: fmt"""${"test"}%s""" == "test"
    check: fmt"""${"test"}%5s""" == " test"
    check: fmt"""${"test"}%-5s""" == "test "

    # Float formatters
    check: fmt"${1}%f" == "1"
    check: fmt"${1}%.3f" == "1.000"
    check: fmt"${1}%3f" == "  1"
    check: fmt"${-1}%08.3f" == "-001.000"
    check: fmt"${-1}%-08.3f" == "-1.00000"
    check: fmt"${-1}%-8.3f" == "-1.000  "
    when defined(js):
      check: fmt"${1}%e" == "1e+0"
    else:
      check: fmt"${1}%e" == "1.000000e+00"
import boost.richstring,
       strutils,
       boost.parsers,
       unittest

{.warning[Deprecated]: off.}

suite "richstring":
  test "string interpolation":
    # Simple cases
    check: fmt"Hello, world!" == "Hello, world!"
    let v = 1
    check: fmt"v = $v" == "v = 1"
    check: fmt"v = $$v" == "v = $v"
    let s = "string"
    check: not compiles(fmt(s))
    check: fmt"${s[0..2].toUpperAscii}" == "STR"

    # Int formatters
    check: fmt"$v%" == "1%"
    check: fmt"$v%%" == "1%"
    check: fmt"$v%d" == "1"
    check: fmt"${-10}%04d" == "-010"
    check: fmt"${-10}%-04d" == "-100"
    check: fmt"${-10}%4d" == " -10"
    check: fmt"${-10}%-4d" == "-10 "
    check: fmt"${10}%x" == "a"
    check: fmt"0x${10}%02x" == "0x0a"
    check: fmt"${10}%X" == "A"
    check: fmt"0x${10}%02X" == "0x0A"

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
    elif defined(windows):
      check: fmt"${1}%e" == "1.000000e+000"
    else:
      check: fmt"${1}%e" == "1.000000e+00"

    # Escape characters
    check: fmt"\x0A" == "\L"
    check: fmt"\10" == "\L"
    check: fmt"\L" == "\L"
    check: fmt"$$\L" == "$\L"
    check: fmt"""${"\L"}""" == "\L"

    # Multiline
    check: fmt"""
test:
"test":
${1}%02d
${2}%02d
""".strip == "test:\n\"test\":\n01\n02"

    check: fmt("a\r\n\r\lb") == "a\r\n\r\lb"
    check: fmt"a\r\n\r\lb" == "a\r\n\r\lb"
    check: fmt("a\n\r\l\rb") == "a\n\r\l\rb"
    check: fmt"a\n\r\l\rb" == "a\n\r\l\rb"

    check: fmt"""foo

    bar""" == """foo

    bar"""

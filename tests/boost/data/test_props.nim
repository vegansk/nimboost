import boost.data.props, unittest

suite "Props":
  test "Props":
    var p = {"a": "a", "b": "b", "a": "c"}.newProps
    p["a"] = "A"
    p.add("b", "B")
    check: p["a"] == "A"
    check: p["b"] == "b, B"

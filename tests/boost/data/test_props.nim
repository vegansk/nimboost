import boost.data.props, unittest

suite "Props":
  test "Props":
    var p = {"a": "a", "b": "b", "a": "c"}.newProps
    p["a"] = "A"
    p.add("b", "B")
    check: p["a"] == "A"
    check: p["b"] == "b,B"
    p["a"] = "a"
    p["b"] = "b"
    p["c"] = "c"
    for n, v in p:
      check: n == v
    check: p.toSeq == @{"a": "a", "b": "b", "c": "c"}

    p.add("a", "A", delimiter="|")
    check: p["a"] == "a|A"

    p.add("a", "A", overwrite = true)
    check: p["a"] == "A"
    p.clear
    check: p.len == 0

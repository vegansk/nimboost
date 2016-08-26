import boost.data.stackm,
       unittest

suite "StackM":
  test "Operations":
    var s = newStackM[int]()
    s.push(1)
    check: s.len == 1
    s.push(2)
    check: s.len == 2
    s.push(3)
    check: s.len == 3
    check: s.pop == 3
    check: s.len == 2
    check: s.pop == 2
    check: s.len == 1
    check: s.pop == 1
    check: s.len == 0

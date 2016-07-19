import unittest, boost.data.rbtreem, sets, random, sequtils, algorithm, random

suite "RBTree":
  
  test "RBTreeM - initialization":
    let t = newRBSetM[int]()
    check: t.len == 0 
    # Value's type is void
    check: not compiles(toSeq(t.values()))
    # But we have keys always
    check: compiles(toSeq(t.keys()))
    var x = 0
    for k in t:
      inc x
    check: x == 0

  test "RBTreeM - insert":
    var t = newRBTreeM[int, string]()
    for i in 1..100:
      t.add(i, $i)
    for i in 1..100:
      t.add(i, $i)
    check: t.len == 100
    check: toSeq(t.keys()) == toSeq(1..100)
    check: toSeq(t.values()) == toSeq(1..100).mapIt($it)
    for i in 1..100:
      check: t.hasKey(i)
    check: t.min == 1
    check: t.max == 100

  test "RBTreeM - equality":
    var t1 = mkRBTreeM([(1, "a"), (2, "b"), (3, "c")])
    var t2 = mkRBTreeM([(3, "c"), (2, "b"), (1, "a")])
    check: t1 == t2
    check: t1 != t2.add(4, "d")

    var t3 = mkRBSetM([1, 2, 3])
    var t4 = mkRBSetM([3, 1, 2])
    check: t3 == t4
    check: t3 != t4.add(4)

  test "RBTreeM - delete":
    var t1 = mkRBSetM([1, 2, 3, 4, 5])
    var t2 = mkRBSetM([1, 2, 3, 4])
    check: t1.del(5) == t2
    check: t1.len == 4
    check: t1.del(1).len == 3
    check: t1.del(3).len == 2
    check: t1.del(2).len == 1
    t1.del(4)
    check: t1.del(4).len == 0

  include shuffle
    
  test "RBTreeM - stress":
    randomize(1234)
    var t = newRBSetM[int]()
    const SIZE = 100_000
    var indices = newSeq[int](SIZE)
    for i in 0..<SIZE:
      t.add(i)
      indices[i] = i
      check: t.len == i + 1
    indices.shuffle
    for j in 0..<SIZE:
      let i = indices[j]
      check: t.hasKey(i) == true
      t.del(i)
      check: t.hasKey(i) == false
      check: t.len == SIZE - j - 1

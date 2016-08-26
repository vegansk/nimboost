import unittest, boost.data.rbtree, sets, random, sequtils, algorithm, random

suite "RBTree":
  test "Initialization":
    let t = newRBSet[int]()
    discard t

  test "Insert":
    check: newRBTree[int, string]().isLeaf
    check: newRBTree[int, string]().add(1, "a").add(2, "b").add(3, "c").isBranch
    check: newRBSet[int]().isLeaf
    check: newRBSet[int]().add(1).add(2).add(3).isBranch

    check: toSeq(mkRBSet([1, 2, 3]).items) == @[1, 2, 3]
    check: toSeq(mkRBSet([1, 2, 3]).keys) == @[1, 2, 3]
    let t = mkRBTree([(1, "a"), (2, "b"), (3, "c")])
    check: toSeq(t.pairs) == @[(1, "a"), (2, "b"), (3, "c")]
    check: toSeq(t.values) == @["a", "b", "c"]

  test "Find":
    var t = newRBTree[int, string]()
    for i in 0..100:
      t = t.add(i, $i)
    for i in 0..100:
      check: t.hasKey(i)
      check: t.getOrDefault(i) == $i

  test "Delete":
    var t = newRBSet[int]()
    for i in 1..5:
      t = t.add(i)
    for i in 1..5:
      t = t.del(i)

  test "Length":
    var t = mkRBTree([(1, "a"), (2, "b"), (3, "c")])
    check: t.len == 3
    t = t.del(100)
    check: t.len == 3
    t = t.del(1)
    check: t.len == 2
    var s = mkRBSet([1,2,3,4])
    check: s.len == 4
    s = s.del(100)
    check: s.len == 4
    s = s.del(1)
    check: s.len == 3

  include shuffle

  test "Stress":
    randomize(1234)
    var t = newRBSet[int]()
    const SIZE = 10_000
    var indices = newSeq[int](SIZE)
    for i in 0..<SIZE:
      t = t.add(i)
      indices[i] = i
      check: t.len == i + 1
    indices.shuffle
    for j in 0..<SIZE:
      let i = indices[j]
      check: t.hasKey(i) == true
      t = t.del(i)
      check: t.hasKey(i) == false
      check: t.len == SIZE - j - 1

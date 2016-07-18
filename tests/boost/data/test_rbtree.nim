import unittest, boost.data.rbtree, sets, random, sequtils, algorithm, random

suite "RBTree":
  test "RBTree - initialization":
    let t = newRBTree[int, void]()

  test "RBTree - insert":
    check: newRBTree[int, string]().isLeaf
    check: newRBTree[int, string]().add(1, "a").add(2, "b").add(3, "c").isBranch
    check: newRBTree[int,void]().isLeaf
    check: newRBTree[int,void]().add(1).add(2).add(3).isBranch

  test "RBTree - find":
    var t = newRBTree[int, string]()
    for i in 0..100:
      t = t.add(i, $i)
    echo t
    for i in 0..100:
      check: t.hasKey(i)
      check: t.getOrDefault(i) == $i

  test "RBTree - delete":
    var t = newRBTree[int, void]()
    for i in 1..5:
      t = t.add(i)
    for i in 1..5:
      t = t.del(i)
      
  proc shuffle[T](xs: var openarray[T]) =
    for i in countup(1, xs.len - 1):
      let j = random(succ i)
      swap(xs[i], xs[j])
    
  test "RBTree - stress":
    randomize(1234)
    var t = newRBTree[int,void]()
    const SIZE = 100_000
    var indices = newSeq[int](SIZE)
    for i in 0..<SIZE:
      t = t.add(i)
      indices[i] = i
      # check: t.len == i + 1
    indices.shuffle
    for j in 0..<SIZE:
      let i = indices[j]
      check: t.hasKey(i) == true
      t = t.del(i)
      check: t.hasKey(i) == false
      # check: t.len == SIZE - j - 1

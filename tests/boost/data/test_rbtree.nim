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
    for i in 0..100:
      check: t.hasKey(i)
      check: t.getOrDefault(i) == $i

  test "RBTree - delete":
    var t = newRBTree[int, void]()
    for i in 1..5:
      t = t.add(i)
    echo t
    for i in 1..5:
      t = t.del(i)
      echo t
      
    

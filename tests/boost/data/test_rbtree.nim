import unittest, boost.data.rbtree, sets, random, sequtils, algorithm, random

suite "RBTree":
  test "RBTree - initialization":
    let t = newRBTree[int, void]()

  test "RBTree - insert":
    var t = newRBTree[int, string]()
    t = t.add(1, "a").add(2, "b").add(3, "c")
    echo t

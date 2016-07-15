import unittest, boost.data.rbtree, sets, random, sequtils, algorithm, random

suite "RBTree":
  test "RBTree - initialization":
    let t = newRBTree[int, void]()

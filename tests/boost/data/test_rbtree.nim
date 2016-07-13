import unittest, boost.data.rbtree, sets, random, sequtils, algorithm, random

suite "RBTree":
  
  test "RBTree - initialization":
    let t = newRBTree[int]()
    check: t.len == 0 
    # Value's type is void
    check: not compiles(toSeq(t.values()))
    # But we have keys always
    check: compiles(toSeq(t.keys()))
    var x = 0
    for k in t:
      inc x
    check: x == 0

  test "RBTree - insert (internal)":
    var t = newRBTree[int]()
    t.add(1).add(2).add(3).add(4).add(5)

    check: t.root.k == 2
    check: t.root.l.k == 1
    check: t.root.l.l.isNil and t.root.l.r.isNil
    check: t.root.r.k == 4
    check: t.root.r.l.k == 3
    check: t.root.r.l.l.isNil and t.root.r.l.r.isNil
    check: t.root.r.r.k == 5

    t.add(6).add(7).add(8)

    check: t.root.k == 4
    check: t.root.l.k == 2
    check: t.root.l.l.k == 1

  test "RBTree - insert":
    var t = newRBTree[int, string]()
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

  test "RBTree - equality":
    var t1 = newRBTree[int, string]().add(1, "a").add(2, "b").add(3, "c")
    var t2 = newRBTree[int, string]().add(3, "c").add(2, "b").add(1, "a")
    check: t1 == t2
    check: t1 != t2.add(4, "d")

    var t3 = newRBTree[int]().add(1).add(2).add(3)
    var t4 = newRBTree[int]().add(3).add(1).add(2)
    check: t3 == t4
    check: t3 != t4.add(4)

  test "RBTree - delete (internal)":
    var t = newRBTree[int]().add(1).add(2).add(3).add(4).add(5)

    var res = t.root.bstDelete(t.root)
    check: res.root.k == 3
    check: res.root.l.p == res.root
    check: res.root.r.p == res.root
    res = res.root.bstDelete(res.root.l)
    check: res.root.l.isNil
    res = res.root.bstDelete(res.root.r)
    check: res.root.r.k == 5

  test "RBTree - delete":
    var t1 = newRBTree[int]().add(1).add(2).add(3).add(4).add(5)
    var t2 = newRBTree[int]().add(1).add(2).add(3).add(4)
    check: t1.del(5) == t2
    check: t1.len == 4
    check: t1.del(1).len == 3
    check: t1.del(3).len == 2
    check: t1.del(2).len == 1
    t1.del(4)
    check: t1.del(4).len == 0

  proc shuffle[T](xs: var openarray[T]) =
    for i in countup(1, xs.len - 1):
      let j = random(succ i)
      swap(xs[i], xs[j])
    
  test "RBTree - stress":
    randomize(1234)
    var t = newRBTree[int]()
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

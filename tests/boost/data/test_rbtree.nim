import unittest, boost.data.rbtree, sets, random, sequtils, algorithm

suite "RBTree":
  
  test "RBTree - initialization":
    let nn = RBNIl[int,void]()
    check: nn.isNil
    expect Exception:
      discard nn.key
    var x = 0
    for k in nn:
      inc x
    check: x == 0

  # test "RBTree - insert":
  #   var (root, ok) = RBNilNode[int]().insert(1)
  #   require: ok == true
  #   check: root.value == 1
  #   (root, ok) = root.insert(2)
  #   require: ok == true
  #   check: root.value == 1
  #   (root, ok) = root.insert(3)
  #   require: ok == true
  #   check: root.value == 2
  #   for x in 4..10:
  #     (root, ok) = root.insert(x)
  #   echo root
  #   (root, ok) = root.insert(10)
  #   check: ok == false

  # test "RBTree - delete":
  #   var (root, ok) = (RBNilNode[int](), true)
  #   for i in [13, 8, 17, 1, 11, 15, 25, 6, 22, 27]:
  #     (root, ok) = root.insert(i)
  #   echo root
  #   for i in root:
  #     echo i
  #   (root, ok) = root.delete(13)
  #   echo root

  # test "RBTree - stress test":
  #   proc stressIter(cnt: int) =
  #     var vals = initSet[int]()
  #     for i in 1..cnt:
  #       vals.incl(random(cnt * 2))
  #     var (root, ok) = (RBNilNode[int](), true)
  #     for v in vals:
  #       (root, ok) = root.insert(v)
  #     var valsS = sequtils.toSeq(vals.items)
  #     sort(valsS, cmp)
  #     var rootS = sequtils.toSeq(root.items)
  #     check: valsS == rootS

  #   for x in 1..10000:
  #     stressIter(100)

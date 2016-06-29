import unittest, boost.data.rbtree

suite "RBTree":
  
  test "RBTree - initialization":
    let nn = RBNIlNode[int]()
    check: nn.isNil
    expect Exception:
      discard nn.value
    check: nn.left.isNil
    check: nn.right.isNil
    check: nn.parent.isNil
    check: nn.color == RBNodeColor.BLACK
    
    let n = newRBNode(100)
    check: not n.isNil
    check: n.value == 100
    check: n.color == RBNodeColor.RED
    check: n.left.isNil
    check: n.left.color == RBNodeColor.BLACK
    check: n.right.isNil
    check: n.right.color == RBNodeColor.BLACK
    check: n.parent.isNil

  test "RBTree - insert":
    var (root, ok) = RBNilNode[int]().insert(1)
    require: ok == true
    check: root.value == 1
    (root, ok) = root.insert(2)
    require: ok == true
    check: root.value == 1
    (root, ok) = root.insert(3)
    require: ok == true
    check: root.value == 2
    for x in 4..10:
      (root, ok) = root.insert(x)
    echo root

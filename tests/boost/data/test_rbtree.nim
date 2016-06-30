import unittest, boost.data.rbtree

suite "RBTree":
  
  test "RBTree - initialization":
    let nn = RBNIlNode[int]()
    check: nn.isNil
    expect Exception:
      discard nn.value

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
    (root, ok) = root.insert(10)
    check: ok == false

  test "RBTree - delete":
    var (root, ok) = (RBNilNode[int](), true)
    for i in [13, 8, 17, 1, 11, 15, 25, 6, 22, 27]:
      (root, ok) = root.insert(i)
    echo root
    for i in root:
      echo i
    (root, ok) = root.delete(13)
    echo root

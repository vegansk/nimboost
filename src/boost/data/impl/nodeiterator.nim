# Immitate closure iterator (see https://github.com/nim-lang/Nim/issues/4695)
type
  NodeIterator[K,V] = ref object
    stack: StackM[Node[K,V]]

when compiles(RBTree):
  type Tree[K,V] = RBTree[K,V]
else:
  type Tree = RBTreeM

proc newNodeIterator[K,V](t: Tree[K,V]): NodeIterator[K,V] =
  new result
  result.stack = newStackM[Node[K,V]]()
  var root = t.root
  while root.isBranch:
    result.stack.push(root)
    root = root.l
proc hasNext(n: NodeIterator): bool = not n.stack.isEmpty
proc nextNode[K,V](n: var NodeIterator[K,V]): Node[K,V] =
  assert n.hasNext, "Empty iterator"
  result = n.stack.pop
  var root = result.r
  while root.isBranch:
    n.stack.push(root)
    root = root.l

proc equalsImpl[K;V: NonVoid](l, r: Tree[K,V]): bool =
  var i1 = newNodeIterator(l)
  var i2 = newNodeIterator(r)
  result = true
  while true:
    let f1 = not i1.hasNext
    let f2 = not i2.hasNext
    if f1 and f2:
      break
    elif f1 != f2:
      return false
    let r1 = i1.nextNode
    let r2 = i2.nextNode
    if r1.k != r2.k or r1.v != r2.v:
      return false

proc equalsImpl[K](l, r: Tree[K,void]): bool =
  var i1 = newNodeIterator(l)
  var i2 = newNodeIterator(r)
  result = true
  while true:
    let f1 = not i1.hasNext
    let f2 = not i2.hasNext
    if f1 and f2:
      break
    elif f1 != f2:
      return false
    let r1 = i1.nextNode
    let r2 = i2.nextNode
    if r1.k != r2.k:
      return false

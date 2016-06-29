import boost.typeclasses

## The implementation of the Red-Black Tree

####################################################################################################
# Type

type
  RBNodeColor* {.pure.} = enum BLACK, RED
  RBNode*[T] = ref RBNodeObj[T]
  RBNodeObj[T] = object 
    v: T
    c: RBNodeColor
    l, r, p: RBNode[T]

proc RBNilNode*[T]: RBNode[T] {.inline.} = nil
proc newRBNode*[T](value: T, color: RBNodeColor, left, right, parent: RBNode[T]): RBNode[T] {.inline.} =
  RBNode[T](v: value, l: left, r: right, p: parent, c: color)
proc newRBNode*[T](value: T): RBNode[T] {.inline.} =
  newRBNode(value, RBNodeColor.RED, RBNilNode[T](), RBNilNode[T](), RBNilNode[T]())

proc value*[T](n: RBNode[T]): auto {.inline.} =
  assert n != nil
  n.v
proc left*[T](n: RBNode[T]): auto {.inline.} = (if n.isNil: RBNilNode[T]() else: n.l)
proc right*[T](n: RBNode[T]): auto {.inline.} = (if n.isNil: RBNilNode[T]() else: n.r)
proc parent*[T](n: RBNode[T]): auto {.inline.} = (if n.isNil: RBNilNode[T]() else: n.p)
proc color*[T](n: RBNode[T]): auto {.inline.} = (if n.isNil: RBNodeColor.BLACK else: n.c)

proc grandParent*[T](n: RBNode[T]): RBNode[T] {.inline.} = n.parent.parent
proc uncle*[T](n: RBNode[T]): RBNode[T] {.inline.} =
  let g = n.grandParent
  if n.parent == g.left:
    g.right
  else:
    g.left

proc rotateLeft[T](n: RBNode[T]) =
  assert(not n.r.isNil)
  let pivot = n.r
  pivot.p = n.p
  if not n.p.isNil:
    if n.p.l == n:
      n.p.l = pivot
    else:
      n.p.r = pivot
  n.r = pivot.l
  if not pivot.l.isNil:
    pivot.l.p = n
  n.p = pivot
  pivot.l = n

proc rotateRight[T](n: RBNode[T]) =
  assert(not n.r.isNil)
  let pivot = n.l
  pivot.p = n.p
  if not n.p.isNil:
    if n.p.l == n:
      n.p.l = pivot
    else:
      n.p.r = pivot
  n.l = pivot.r
  if not pivot.r.isNil:
    pivot.r.p = n
  n.p = pivot
  pivot.r = n

proc insertCase2(n: RBNode)
proc insertCase3(n: RBNode)
proc insertCase4(n: RBNode)
proc insertCase5(n: RBNode)
  
proc insertCase1(n: RBNode) =
  if n.p.isNil:
    n.c = RBNodeColor.BLACK
  else:
    n.insertCase2

proc insertCase2(n: RBNode) =
  if n.p.c == RBNodeColor.BLACK:
    return
  else:
    n.insertCase3

proc insertCase3(n: RBNode) =
  let u = n.uncle
  if not(u.isNil) and u.c == RBNodeColor.RED and n.p.c == RBNodeColor.RED:
    n.p.c = RBNodeColor.BLACK
    u.c = RBNodeColor.BLACK
    let g = n.grandParent
    g.c = RBNodeColor.RED
    g.insertCase1
  else:
    n.insertCase4

proc insertCase4(n: RBNode) =
  let g = n.grandParent
  var nn = n
  if n == n.p.r and n.p == g.l:
    n.p.rotateLeft
    nn = n.l
  elif n == n.p.l and n.p == g.r:
    n.p.rotateRight
    nn = n.r
  n.insertCase5

proc insertCase5(n: RBNode) =
  let g = n.grandParent
  n.p.c = RBNodeColor.BLACK
  g.c = RBNodeColor.RED
  if n == n.p.l and n.p == g.l:
    g.rotateRight
  else:
    g.rotateLeft

proc fixInsert(n: RBNode) =
  n.insertCase1
  
####################################################################################################
# Tree API

proc insert*[T](r: RBNode[T], v: T): (RBNode[T], bool) =
  if r.isNil:
    let n = newRBNode(v)
    n.fixInsert
    return (n, true)
  else:
    var curr = r
    var parent = r
    while not curr.isNil:
      if curr.v == v:
        return (r, false)
      parent = curr
      curr = if curr.v > v: curr.l else: curr.r
    let n = newRBNode(v)
    n.p = parent
    n.fixInsert
    if r.p.isNil:
      return (r, true)
    else:
      return (r.p, true)
      
proc delete*[T](n: RBNode[T], v: T): (RBNode[T], bool) = discard
proc find*[T](n: RBNode[T], v: T): (RBNode[T], bool) = discard

iterator items*[T](n: RBNode[T]): T = discard
  

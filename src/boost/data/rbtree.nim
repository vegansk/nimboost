## The implementation of the Red-Black Tree

####################################################################################################
# Type

type
  RBNodeColor = enum BLACK, RED
  RBNode*[T] = ref RBNodeObj[T]
  RBNodeObj[T] = object 
    v: T
    c: RBNodeColor
    l, r, p: RBNode[T]

proc RBNilNode*[T]: RBNode[T] {.inline.} = nil
proc newRBNode[T](value: T, color: RBNodeColor, left, right, parent: RBNode[T]): RBNode[T] {.inline.} =
  RBNode[T](v: value, l: left, r: right, p: parent, c: color)
proc newRBNode[T](value: T): RBNode[T] {.inline.} =
  newRBNode(value, RED, RBNilNode[T](), RBNilNode[T](), RBNilNode[T]())

proc value*(n: RBNode): auto {.inline.} =
  assert(not(n.isNil))
  n.v

proc left(n: RBNode): auto {.inline.} = (if n.isNil: RBNilNode[type(n.v)]() else: n.l)

proc right(n: RBNode): auto {.inline.} = (if n.isNil: RBNilNode[type(n.v)]() else: n.r)

proc parent(n: RBNode): auto {.inline.} = (if n.isNil: RBNilNode[type(n.v)]() else: n.p)

proc color(n: RBNode): auto {.inline.} = (if n.isNil: BLACK else: n.c)

# This implementation is based on the article
# https://en.wikipedia.org/wiki/Red%E2%80%93black_tree

proc grandParent(n: RBNode): RBNode {.inline.} = n.parent.parent

proc uncle(n: RBNode): RBNode {.inline.} =
  let g = n.grandParent
  if n.parent == g.left:
    g.right
  else:
    g.left

proc sibling(n: RBNode): RBNode {.inline.} =
  if n.parent.left == n:
    n.parent.right
  else:
    n.parent.left

proc rotateLeft(n: RBNode) {.inline.} =
  if n.r.isNil:
    return
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

proc rotateRight(n: RBNode) =
  if n.l.isNil:
    return
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
    n.c = BLACK
  else:
    n.insertCase2

proc insertCase2(n: RBNode) =
  if n.p.c == BLACK:
    return
  else:
    n.insertCase3

proc insertCase3(n: RBNode) =
  let u = n.uncle
  if not(u.isNil) and u.c == RED and n.p.c == RED:
    n.p.c = BLACK
    u.c = BLACK
    let g = n.grandParent
    g.c = RED
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
  if g.isNil:
    return
  n.p.c = BLACK
  g.c = RED
  if n == n.p.l and n.p == g.l:
    g.rotateRight
  else:
    g.rotateLeft

proc fixInsert(n: RBNode) =
  n.insertCase1

proc deleteCase2(n: RBNode)
proc deleteCase3(n: RBNode)
proc deleteCase4(n: RBNode)
proc deleteCase5(n: RBNode)
proc deleteCase6(n: RBNode)

proc deleteCase1(n: RBNode) =
  if not n.p.isNil:
    n.deleteCase2

proc deleteCase2(n: RBNode) =
  let s = n.sibling
  if s.c == RED:
    n.p.c = RED
    s.c = BLACK
    if n == n.p.l:
      n.p.rotateLeft
    else:
      n.p.rotateRight
  n.deleteCase3

proc deleteCase3(n: RBNode) =
  let s = n.sibling
  if n.p.c == BLACK and s.c == BLACK and (s.l.isNil or s.l.c == BLACK) and (s.r.isNil or s.r.c == BLACK):
    s.c = RED
    n.p.deleteCase1
  else:
    n.deleteCase4

proc deleteCase4(n: RBNode) =
  let s = n.sibling
  if n.p.c == RED and s.c == BLACK and (s.l.isNil or s.l.c == BLACK) and (s.r.isNil or s.r.c == BLACK):
    s.c = RED
    n.p.c = BLACK
  else:
    n.deleteCase5

proc deleteCase5(n: RBNode) =
  let s = n.sibling
  if s.c == BLACK:
    if n == n.p.l and (s.r.isNil or s.r.c == BLACK) and not(s.l.isNil) and s.l.c == RED:
      s.c = RED
      s.l.c = BLACK
      s.rotateRight
    elif n == n.p.r and (s.l.isNil or s.l.c == BLACK) and not(s.r.isNil) and s.r.c == RED:
      s.c = RED
      s.r.c = BLACK
      s.rotateLeft
  n.deleteCase6

proc deleteCase6(n: RBNode) =
  let s = n.sibling
  s.c = n.p.c
  n.p.c = BLACK
  if n == n.p.l:
    s.r.c = BLACK
    n.p.rotateLeft
  else:
    s.l.c = BLACK
    n.p.rotateRight

proc replaceNode(dst, src: RBNode) =
  if dst.p.l == dst:
    dst.p.l = src
  else:
    dst.p.r = src
  src.p = dst.p
  dst.p = nil
  dst.l = nil
  dst.r = nil

proc deleteOneChild(n: RBNode) =
  let ch = if not n.r.isNil: n.r else: n.l
  replaceNode(n, ch)
  if n.c == BLACK:
    if ch.c == RED:
      ch.c = BLACK
    else:
      ch.deleteCase1

proc findMax[T](n: RBNode[T]): RBNode[T] {.inline.} =
  if n.isNil:
    result = n
  else:
    result = n
    while not result.r.isNil:
      result = result.r
    
proc findMin[T](n: RBNode[T]): RBNode[T] {.inline.} =
  if n.isNil:
    result = n
  else:
    result = n
    while not result.l.isNil:
      result = result.l
    
####################################################################################################
# Tree API

proc insert*[T](r: RBNode[T], v: T): (RBNode[T], bool) =
  if r.isNil:
    let n = newRBNode(v)
    n.fixInsert
    result = (n, true)
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
    if n.v < n.p.v:
      n.p.l = n
    else:
      n.p.r = n
    n.fixInsert
    if r.p.isNil:
      result = (r, true)
    else:
      result = (r.p, true)
  assert(result[0].c == BLACK)

proc delete*[T](r: RBNode[T], v: T): (RBNode[T], bool) =
  var curr = r
  while not curr.isNil:
    if curr.v == v: break
    curr = if v < curr.v: curr.l else: curr.r
  if curr.isNil:
    return (curr, false)

  if curr.l.isNil and curr.r.isNil:
    if curr.p.isNil:
      return (curr.p, true)
    if curr.p.l == curr:
      curr.p.l = curr.l
    else:
      curr.p.r = curr.r
    return (r, true)
  else:
    let rn = if not curr.l.isNil: curr.l.findMax else: curr.r.findMin
    curr.v = rn.v
    if not rn.l.isNil or not rn.r.isNil:
      rn.deleteOneChild
    else:
      if rn.p.l == rn:
        rn.p.l = rn.l
      else:
        rn.p.r = rn.r
    return (r, true)

proc find*[T](n: RBNode[T], v: T): (RBNode[T], bool) = discard

iterator items*[T](n: RBNode[T]): T =
  var next = n
  while not next.l.isNil:
    next = next.l
  block loop:
    while true:
      yield next.v
      if not next.r.isNil:
        next = next.r
        while not next.l.isNil:
          next = next.l
      else:
        while true:
          if next.p.isNil:
            break loop
          if next.p.l == next:
            next = next.p
            break
          next = next.p

proc mkTab(tab, s: int): string =
  if tab == 0:
    result = ""
  else:
    result = newString(tab + s)
    for i in 0..<tab:
      result[i] = ' '
    result[tab] = '\\'
    for i in (tab+1)..<(tab+s):
      result[i] = '_'

const TAB_STEP = 2
    
# TODO: It's ugly for now, need another implementation
proc treeReprImpl[T](n: RBNode[T], tab: int): string =
  result = mkTab(tab, TAB_STEP)
  if n.isNil:
    result.add("[NIL]\n")
  else:
    result.add("[" & $n.v & "]\n")
    result.add(treeReprImpl(n.l, tab + TAB_STEP))
    result.add(treeReprImpl(n.r, tab + TAB_STEP))
    
proc treeRepr*[T](n: RBNode[T]): string =
  result = treeReprImpl(n, 0)
  result.setLen(result.len - 1)

proc `$`*[T](n: RBNode[T]): string = n.treeRepr
  

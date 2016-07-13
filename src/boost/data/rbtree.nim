## The implementation of the Red-Black Tree

import boost.typeclasses

####################################################################################################
# Type

when defined(debug):
  type
    RBNodeColor* = enum BLACK, RED
    RBNode*[K,V] = ref RBNodeObj[K,V]
    RBNodeObj*[K,V] = object 
      k*: K
      when not(V is void):
        v*: V
        c*: RBNodeColor
        l*, r*, p*: RBNode[K,V]
    RBTree*[K,V] = ref RBTreeObj[K,V]
    RBTreeObj*[K,V] = object
      root*: RBNode[K,V]
      length*: int
else:
  type
    RBNodeColor = enum BLACK, RED
    RBNode[K,V] = ref RBNodeObj[K,V]
    RBNodeObj[K,V] = object 
      k: K
      when not(V is void):
        v: V
        c: RBNodeColor
        l, r, p: RBNode[K,V]
    RBTree*[K,V] = ref RBTreeObj[K,V]
    RBTreeObj[K,V] = object
      root: RBNode[K,V]
      length: int

proc newRBTree*[K,V]: RBTree[K,V] =
  RBTree[K,V](root: nil, length: 0)

proc newRBTree*[K]: RBTree[K,void] =
  RBTree[K,void](root: nil, length: 0)

proc len*(t: RBTree): auto = t.length

proc newNode[K;V: NonVoid](k: K, v: V, c: RBNodeColor, l, r, p: RBNode[K,V] = nil): RBNode[K,V] {.inline.} =
  RBNode[K,V](k: k, v: v, c: c, l: l, r: r, p: p)

proc newNode[K](k: K, c: RBNodeColor, l, r, p: RBNode[K,void] = nil): RBNode[K,void] {.inline.} =
  RBNode[K,void](k: k, c: c, l: l, r: r, p: p)

template iterateNode(n: RBNode, next: expr, op: stmt): stmt {.immediate.} =
  if not n.isNil:
    var next = n
    while not next.l.isNil:
      next = next.l
    block loop:
      while true:
        # yield next.k
        `op`
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

iterator items*[K,V](t: RBTree[K,V]): K {.closure.} =
  iterateNode(t.root, next):
    yield next.k

iterator keys*(t: RBTree): auto =
  iterateNode(t.root, next):
    yield next.k

iterator pairs*[K;V: NonVoid](t: RBTree[K,V]): (K,V) {.closure.} =
  iterateNode(t.root, next):
    yield (next.k, next.v)

iterator mpairs*[K;V: NonVoid](t: var RBTree[K,V]): (K, var V) =
  iterateNode(t.root, next):
    yield (next.k, next.v)

iterator values*(t: RBTree): auto =
  iterateNode(t.root, next):
    yield next.v

iterator mvalues*[K,V](t: var RBTree[K,V]): var V =
  iterateNode(t.root, next):
    yield next.v

####################################################################################################
# Implementation based on http://www.geeksforgeeks.org/red-black-tree-set-1-introduction-2/

proc isLeftChild(n: RBNode): bool {.inline.} =
  not(n.isNil) and not(n.p.isNil) and n.p.l == n

proc isRightChild(n: RBNode): bool {.inline.} =
  not(n.isNil) and not(n.p.isNil) and n.p.r == n

proc clean(n: RBNode): RBNode {.inline, discardable.} =
  if not(n.isNil):
    n.l = nil
    n.r = nil
    n.p = nil
  n

proc replace(`from`: RBNode, to: RBNode): RBNode {.inline, discardable.} =
  if `from`.isLeftChild:
    `from`.p.l = to
  elif `from`.isRightChild:
    `from`.p.r = to
  if not(to.isNil):
    to.c = `from`.c
    if to.isLeftChild:
      to.p.l = nil
    elif to.isRightChild:
      to.p.r = nil
    to.l = `from`.l
    to.r = `from`.r
    to.p = `from`.p
  if not(`from`.l.isNil):
    `from`.l.p = `to`
  if not(`from`.r.isNil):
    `from`.r.p = `to`
  return `from`

proc cleanParent(n: var RBNode): RBNode {.inline.} =
  if not(n.isNil):
    n.p = nil
  n

proc color(n: RBNode): RBNodeColor {.inline.} =
  if n.isNil: BLACK else: n.c

proc setColor(n: RBNode, c: RBNodeColor) {.inline.} =
  if not(n.isNil):
    n.c = c

proc parent(n: RBNode): RBNode {.inline.} =
  if n.isNil: nil else: n.p

proc left(n: RBNode): RBNode {.inline.} =
  if n.isNil: nil else: n.l

proc right(n: RBNode): RBNode {.inline.} =
  if n.isNil: nil else: n.r

proc bstInsert(root, pt: var RBNode): tuple[root: RBNode, inserted: bool] =
  ## Returns new root and the flag: true for insert, false for update
  if root.isNil:
    return (pt, true)
  var curr = root
  var prev: type(curr)
  while not(curr.isNil):
    prev = curr
    if pt.k < curr.k:
      curr = curr.l
    elif pt.k > curr.k:
      curr = curr.r
    else:
      # Equal keys
      when compiles(pt.v):
        curr.v = pt.v
        pt = curr
      return (root, false)
  if pt.k < prev.k:
    prev.l = pt
  else:
    prev.r = pt
  pt.p = prev
  return (root, true)

proc rotateLeft(root: var RBNode, pt: RBNode) =
  var r = pt.r
  pt.r = r.l
  if not pt.r.isNil:
    pt.r.p = pt
  r.p = pt.p
  if pt.p.isNil:
    root = r
  elif pt.isLeftChild:
    pt.p.l = r
  else:
    pt.p.r = r
  r.l = pt
  pt.p = r

proc rotateRight(root: var RBNode, pt: RBNode) =
  var l = pt.l
  pt.l = l.r
  if not pt.l.isNil:
    pt.l.p = pt
  l.p = pt.p
  if pt.p.isNil:
    root = l
  elif pt.isLeftChild:
    pt.p.l = l
  else:
    pt.p.r = l
  l.r = pt
  pt.p = l

proc fixInsert(root, pt: var RBNode) =
  var ppt: type(pt)
  var gppt: type(pt)

  while pt != root and pt.c != BLACK and pt.p.c == RED:
    ppt = pt.p
    gppt = ppt.p
    if ppt == gppt.l:
      var upt = gppt.r
      if not(upt.isNil) and upt.c == RED:
        gppt.c = RED
        ppt.c = BLACK
        upt.c = BLACK
        pt = gppt
      else:
        if pt == ppt.r:
          rotateLeft(root, ppt)
          pt = ppt
          ppt = pt.p
        rotateRight(root, gppt)
        swap(ppt.c, gppt.c)
        pt = ppt
    else:
      var upt = gppt.l
      if not(upt.isNil) and upt.c == RED:
        gppt.c = RED
        ppt.c = BLACK
        upt.c = BLACK
        pt = gppt
      else:
        if pt == ppt.l:
          rotateRight(root, ppt)
          pt = ppt
          ppt = pt.p
        rotateLeft(root, gppt)
        swap(ppt.c, gppt.c)
        pt = ppt
  root.c = BLACK

proc add*[K;V: NonVoid](t: var RBTree[K,V], k: K, v: V): var RBTree[K,V] {.discardable.} =
  var pt = newNode(k, v, RED)
  var (newRoot, ok) = bstInsert(t.root, pt)
  t.root = newRoot
  if ok:
    inc t.length
    fixInsert(t.root, pt)
  result = t

proc add*[K](t: var RBTree[K,void], k: K): var RBTree[K,void] {.discardable.} =
  var pt = newNode(k, RED)
  var (newRoot, ok) = bstInsert(t.root, pt)
  t.root = newRoot
  if ok:
    inc t.length
    fixInsert(t.root, pt)
  result = t

proc findKey[K,V](n: RBNode[K,V], k: K): RBNode[K,V] {.inline.} =
  var curr = n
  while not(curr.isNil):
    if k == curr.k:
      return curr
    elif k < curr.k:
      curr = curr.l
    else:
      curr = curr.r
  return nil

proc findMin[K,V](n: RBNode[K,V]): RBNode[K,V] {.inline.} =
  if n.isNil:
    return nil
  var curr = n
  while not(curr.l.isNil):
    curr = curr.l
  return curr

proc findMax[K,V](n: RBNode[K,V]): RBNode[K,V] {.inline.} =
  if n.isNil:
    return nil
  var curr = n
  while not(curr.r.isNil):
    curr = curr.r
  return curr

proc hasKey*[K,V](t: RBTree[K,V], k: K): bool =
  t.root.findKey(k) != nil

proc getOrDefault*[K,V: NonVoid](t: RBTree[K,V], k: K): V =
  let n = t.root.findKey(k)
  if not n.isNil:
    result = n.v

proc min*[K,V](t: RBTree[K,V]): K =
  let n = t.root.findMin()
  assert n != nil
  n.k
  
proc max*[K,V](t: RBTree[K,V]): K =
  let n = t.root.findMax()
  assert n != nil
  n.k

proc `==`*[K;V: NonVoid](l, r: RBTree[K,V]): bool =
  var i1 = (iterator(t: RBTree[K,V]): (K,V))rbtree.pairs
  var i2 = (iterator(t: RBTree[K,V]): (K,V))rbtree.pairs
  result = true
  while true:
    var r1 = i1(l)
    var r2 = i2(r)
    let f1 = i1.finished
    let f2 = i2.finished
    if f1 and f2:
      break
    elif f1 != f2:
      return false
    if r1[0] != r2[0] or r1[1] != r2[1]:
      return false

proc `==`*[K](l, r: RBTree[K,void]): bool =
  var i1 = (iterator(t: RBTree[K,void]): K)rbtree.items
  var i2 = (iterator(t: RBTree[K,void]): K)rbtree.items
  result = true
  while true:
    let r1 = i1(l)
    let r2 = i2(r)
    let f1 = i1.finished
    let f2 = i2.finished
    if f1 and f2:
      break
    elif f1 != f2:
      return false
    if r1 != r2:
      return false

proc bstDeleteImpl(root, pt: var RBNode): tuple[root: RBNode, deleted: RBNode] {.inline.} = 
  assert(not pt.isNil)

  let haveLeft = not(pt.l.isNil)
  let haveRight = not(pt.r.isNil)
  let isRoot = pt == root

  if not(haveLeft) and not(haveRight):
    if isRoot:
      return (nil, nil)
    else:
      pt.replace(nil)
      return (root, pt)
  elif not(haveLeft) or not(haveRight):
    var n = if haveLeft: pt.l else: pt.r
    if isRoot:
      return (n.cleanParent, pt)
    else:
      pt.replace(n)
      return (root, pt)
  else:
    var n = pt.r.findMin
    pt.replace(n)
    if isRoot:
      return (n, pt)
    else:
      return (root, pt)

when defined(debug):
  proc bstDelete*(root, pt: var RBNode): tuple[root: RBNode, deleted: RBNode] = bstDeleteImpl(root, pt)
else:
  proc bstDelete(root, pt: var RBNode): tuple[root: RBNode, deleted: RBNode] = bstDeleteImpl(root, pt)

proc succ(n: RBNode): RBNode =
  if n.isNil:
    return nil
  elif not n.right.isNil:
    var p = n.right
    while not p.left.isNil:
      p = p.left
    return p
  else:
    var p = n.parent
    var ch = n
    while not p.isNil and ch == p.right:
      ch = p
      p = p.parent
    return p

proc fixDelete(root: var RBNode, n: RBNode) {.inline.} =
  assert(not root.isNil)
  assert(not n.isNil)

  var x = n

  while not x.isNil and x != root and x.color == BLACK:
    if x.isLeftChild:
      var sib = x.parent.right
      if sib.color == RED:
        setColor(sib, BLACK)
        setColor(x.parent, RED)
        rotateLeft(root, x.parent)
        sib = x.parent.right 

      if sib.left.color == BLACK and sib.right.color == BLACK:
        setColor(sib, RED)
        x = x.parent
      else:
        if sib.right.color == BLACK:
          setColor(sib.left, BLACK)
          setColor(sib, RED)
          rotateRight(root, sib)
          sib = x.parent.right
        setColor(sib, x.parent.color)
        setColor(x.parent, BLACK)
        setColor(sib.right, BLACK)
        rotateLeft(root, x.parent)
        x = root
    else:
      var sib = x.parent.left
      if sib.color == RED:
        setColor(sib, BLACK)
        setColor(x.parent, RED)
        rotateRight(root, x.parent)
        sib = x.parent.left 
        
      if sib.right.color == BLACK and sib.left.color == BLACK:
        setColor(sib, RED)
        x = x.parent
      else:
        if sib.left.color == BLACK:
          setColor(sib.right, BLACK)
          setColor(sib, RED)
          rotateLeft(root, sib)
          sib = x.parent.left
        setColor(sib, x.parent.color)
        setColor(x.parent, BLACK)
        setColor(sib.left, BLACK)
        rotateRight(root, x.parent)
        x = root

  setColor(x, BLACK)

# proc del*[K,V](t: var RBTree[K,V], k: K): var RBTree[K,V] {.discardable.} =
#   result = t
#   var n = t.root.findKey(k)
#   if n.isNil:
#     echo "SHIT!"
#     return
#   var res = bstDelete(t.root, n)
#   t.root = res[0]
#   dec t.length
#   if res[1].isNil:
#     return
#   fixDelete(t.root, res[1])

proc removeNode[K,V](root: var RBNode[K,V], n: RBNode[K,V]) =
  var p = n
  if not p.l.isNil and not p.r.isNil:
    var s = p.succ
    p.k = s.k
    when V isnot void:
      p.v = s.v
    p = s
  var repl = if not p.l.isNil: p.l else: p.r
  if not repl.isNil:
    repl.p = p.p
    if p.p.isNil:
      root = repl
    elif p == p.p.l:
      p.p.l = repl
    else:
      p.p.r = repl
    p.clean
    if p.c == BLACK:
      fixDelete(root, repl)
  elif p.p.isNil:
    root = nil
  else:
    if p.c == BLACK:
      fixDelete(root, p)
    if not p.p.isNil:
      if p.p.l == p:
        p.p.l = nil
      elif p.p.r == p:
        p.p.r = nil
      p.p = nil
          
proc del*[K,V](t: var RBTree[K,V], k: K): var RBTree[K,V] {.discardable.} =
  result = t
  var n = t.root.findKey(k)
  if n.isNil:
    return
  removeNode(t.root, n)
  dec t.length

# proc del*[K,V](t: var RBTree[K,V], k: K): var RBTree[K,V] {.discardable.} =
#   result = t
#   var n = t.root.findKey(k)
#   if n.isNil:
#     return
#   dec t.length
#   if not(n.left.isNil) and not(n.right).isNil:
#     var s = n.succ
#     n.k = s.k
#     when V isnot void:
#       n.v = s.v
#       n = s

#   var repl = if not(n.left.isNil): n.left else: n.right
#   if not(repl.isNil):
#     repl.p = n.p
#     if n.p.isNil:
#       t.root = repl
#     elif n.isLeftChild:
#       n.p.l = repl
#     else:
#       n.p.r = repl

#     n.l = nil
#     n.r = nil
#     n.p = nil
#     if n.color == BLACK:
#       fixDelete(t.root, repl)
#   elif n.p.isNil:
#     t.root = nil
#   else:
#     if n.c == BLACK:
#       fixDelete(t.root, n)
#     if not(n.p.isNil):
#       if n.isLeftChild:
#         n.p.l = nil
#       elif n.isRightChild:
#         n.p.r = nil
#       n.p = nil
        
####################################################################################################
# Pretty print

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
proc treeReprImpl[K,V](n: RBNode[K,V], tab: int): string =
  result = mkTab(tab, TAB_STEP)
  if n.isNil:
    result.add("[NIL]\n")
  else:
    when V is NonVoid:
      result.add("[" & $n.k & ", " & $n.v & "]\n")
    else:
      result.add("[" & $n.k & "]\n")
    result.add(treeReprImpl(n.l, tab + TAB_STEP))
    result.add(treeReprImpl(n.r, tab + TAB_STEP))
    
proc treeRepr*(t: RBTree): string =
  result = treeReprImpl(t.root, 0)
  result.setLen(result.len - 1)

proc `$`*(n: RBTree): string = n.treeRepr
  

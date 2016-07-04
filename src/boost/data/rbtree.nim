## The implementation of the Red-Black Tree

import boost.typeclasses

####################################################################################################
# Type

type
  RBNodeColor = enum BLACK, RED
  RBNode*[K,V] = ref RBNodeObj[K,V]
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

iterator items*(t: RBTree): auto =
  iterateNode(t.root, next):
    yield next.k

iterator keys*(t: RBTree): auto =
  iterateNode(t.root, next):
    yield next.k

iterator pairs*[K;V: NonVoid](t: RBTree[K,V]): auto =
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

proc bstInsert(root, pt: var RBNode): (RBNode, bool) =
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

proc rotateLeft(root, pt: var RBNode) =
  var r = pt.r
  pt.r = r.l
  if not pt.r.isNil:
    pt.r.p = pt
  r.p = pt.p
  if pt.p.isNil:
    root = r
  elif pt == pt.p.l:
    pt.p.l = r
  else:
    pt.p.r = r
  r.l = pt
  pt.p = r

proc rotateRight(root, pt: var RBNode) =
  var l = pt.l
  pt.l = l.r
  if not pt.l.isNil:
    pt.l.p = pt
  l.p = pt.p
  if pt.p.isNil:
    root = l
  elif pt == pt.p.l:
    pt.p.l = l
  else:
    pt.p.r = l
  l.r = pt
  pt.p = l

proc fixViolation(root, pt: var RBNode) =
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
    fixViolation(t.root, pt)
  result = t

proc findKey[K,V](n: RBNode[K,V], k: K): RBNode[K,V] =
  var curr = n
  while not(curr.isNil):
    if k == curr.k:
      return curr
    elif k < curr.k:
      curr = curr.l
    else:
      curr = curr.r
  return nil

proc findMin[K,V](n: RBNode[K,V]): RBNode[K,V] =
  if n.isNil:
    return nil
  var curr = n
  while not(curr.l.isNil):
    curr = curr.l
  return curr

proc findMax[K,V](n: RBNode[K,V]): RBNode[K,V] =
  if n.isNil:
    return nil
  var curr = n
  while not(curr.r.isNil):
    curr = curr.r
  return curr

proc hasKey*[K,V](t: RBTree[K,V], k: K): bool =
  t.root.findKey(k) != nil

proc min*[K,V](t: RBTree[K,V]): K =
  let n = t.root.findMin()
  assert n != nil
  n.k
  
proc max*[K,V](t: RBTree[K,V]): K =
  let n = t.root.findMax()
  assert n != nil
  n.k
  
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
  

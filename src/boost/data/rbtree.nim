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

proc key(n: RBNode): auto {.inline.} =
  assert(not(n.isNil))
  n.k

proc value[K;V: NonVoid](n: RBNode[K,V]): V {.inline.} =
  assert(not(n.isNil))
  n.v

proc left(n: RBNode): auto {.inline.} = (if n.isNil: nil else: n.l)
proc right(n: RBNode): auto {.inline.} = (if n.isNil: nil else: n.r)
proc parent(n: RBNode): auto {.inline.} = (if n.isNil: nil else: n.p)
proc color(n: RBNode): auto {.inline.} = (if n.isNil: BLACK else: n.c)

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
      when declared(pt.v):
        curr.v = pt.v
        pt = curr
        return (root, false)
  if pt.k < prev.k:
    prev.l = pt
  else:
    prev.r = pt
  pt.p = prev
  return (root, true)

proc fixViolation(root, pt: var RBNode) = discard

proc add*[K;V: NonVoid](t: var RBTree[K,V], k: K, v: V): var RBTree[K,V] {.discardable.} =
  var pt = newNode(k, v, BLACK)
  var (newRoot, ok) = bstInsert(t.root, pt)
  t.root = newRoot
  if ok:
    inc t.length
    fixViolation(t.root, pt)
  result = t
  
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
  

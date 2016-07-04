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

proc RBNil*[K,V]: RBNode[K,V] {.inline.} = nil

proc newNode[K;V: NonVoid](k: K, v: V, c: RBNodeColor, l, r, p: RBNode[K,V]): RBNode[K,V] {.inline.} =
  RBNode(k: k, v: v, c: c, l: l, r: r, p: p)

proc key*(n: RBNode): auto {.inline.} =
  assert(not(n.isNil))
  n.k

proc value*[K;V: NonVoid](n: RBNode[K,V]): V {.inline.} =
  assert(not(n.isNil))
  n.v

proc left[K,V](n: RBNode[K,V]): auto {.inline.} = (if n.isNil: RBNil[K,V]() else: n.l)
proc right[K,V](n: RBNode[K,V]): auto {.inline.} = (if n.isNil: RBNil[K,V]() else: n.r)
proc parent[K,V](n: RBNode[K,V]): auto {.inline.} = (if n.isNil: RBNil[K,V]() else: n.p)
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

iterator items*(n: RBNode): auto =
  iterateNode(n, next):
    yield next.k

iterator pairs*[K;V: NonVoid](n: RBNode[K,V]): auto =
  iterateNode(n, next):
    yield (next.k, next.v)

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
    
proc treeRepr*(n: RBNode): string =
  result = treeReprImpl(n, 0)
  result.setLen(result.len - 1)

proc `$`*(n: RBNode): string = n.treeRepr
  

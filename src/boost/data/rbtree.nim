import boost.typeclasses, boost.types

####################################################################################################
# Type

type
  Color = enum BLACK, RED 
  RBTree*[K,V] = ref RBTreeObj[K,V]
  RBTreeObj[K,V] = object
    case e: bool
    of true:
      discard
    else:
      k: K
      c: Color
      when V isnot void and V isnot Unit:
        v: V
      l,r: RBTree[K,V]

proc newRBtree*[K,V](): RBTree[K,V] =
  RBTree[K,V](e: true)

proc newRBTree[K](c: Color, l: RBTree[K,Unit], k: K, v: Unit, r: RBTree[K,Unit]): RBTree[K,Unit] {.inline.} =
  RBTree[K,Unit](k: k, c: c, l: l, r: r)
proc newRBTree[K;V: NonVoid](c: Color, l: RBTree[K,V], k: K, v: V, r: RBTree[K,V]): RBTree[K,V] {.inline.} =
  RBTree[K,V](k: k, v: v, c: c, l: l, r: r)
proc newRBTree[K](c: Color, l: RBTree[K,void], k: K, r: RBTree[K,void]): RBTree[K,void] {.inline.} =
  RBTree[K,void](k: k, c: c, l: l, r: r)

proc color(t: RBTree): Color {.inline.} =
  case t.e
  of true:
    BLACK
  else:
    t.c

proc isEmpty*(t: RBTree): bool {.inline.} = t.e
proc isLeaf(t: RBTree): bool {.inline.} = t.isEmpty
proc isBranch(t: RBTree): bool {.inline.} = not t.isEmpty
proc isRed(t: RBTree): bool {.inline.} = t.color == RED
proc isBlack(t: RBTree): bool {.inline.} = t.color == BLACK

proc value[K;V: NonVoid](t: RBTree[K,V]): V {.inline.} =
  assert t.isBranch, "Can't get value of leaf"
  when V is Unit:
    ()
  else:
    t.v

proc balance[K,V](a: RBTree[K,V], k: K, v: V, b: RBTree[K,V]): RBTree[K,V] {.inline.} =
  if a.isRed and b.isRed:
    result = newRBTree(RED, newRBTree(BLACK, a.l, a.k, a.value, a.r), k, v, newRBtree(BLACK, b.l, b.k, b.value, b.r))
  elif a.isRed and a.l.isRed:
    result = newRBtree(RED, newRBTree(BLACK, a.l.l, a.l.k, a.l.value, a.l.r), a.k, a.value, newRBTree(BLACK, a.r, k, v, b))
  elif a.isRed and a.r.isRed:
    result = newRBTree(RED, newRBtree(BLACK, a.l, a.k, a.value, a.r.l), a.r.k, a.r.value, newRBTree(BLACK, a.r.r, k, v, b))
  elif b.isRed and b.r.isRed:
    result = newRBtree(RED, newRBTree(BLACK, a, k, v, b.l), b.k, b.value, newRBTree(BLACK, b.r.l, b.r.k, b.r.value, b.r.r))
  elif b.isRed and b.l.isRed:
    result = newRBtree(RED, newRBTree(BLACK, a, k, v, b.l.l), b.l.k, b.l.value, newRBTree(BLACK, b.l.r, b.k, b.value, b.r))
  else:
    result = newRBTree(BLACK, a, k, v, b)

proc add*[K;V: NonVoid](t: RBTree[K,V], k: K, v: V): RBTree[K,V] =
  proc ins(t: RBTree[K,V]): RBTree[K,V] =
    if t.isEmpty:
      result = newRBtree(RED, newRBTree[K,V](), k, v, newRBTree[K,V]())
    elif t.isBlack:
      if k < t.k:
        result = balance(ins(t.l), t.k, t.value, t.r)
      elif k > t.k:
        result = balance(t.l, t.k, t.value, ins(t.r))
      else:
        result = t
    else:
      if k < t.k:
        result = newRBTree(RED, ins(t.l), t.k, t.value, t.r)
      elif k > t.k:
        result = newRBTree(RED, t.l, t.k, t.value, ins(t.r))
      else:
        result = t
  result = ins(t)
  result.c = BLACK

proc add*[K](t: RBTree[K,void], k: K): RBTree[K,void] = discard
proc del*[K,V](t: RBTree[K,V], k: K): RBTree[K,V] = discard
proc hasKey*[K,V](t: RBTree[K,V], k: K): bool = discard
proc getOrDefault*[K;V: NonVoid](t: RBTree[K,V], k: K): V = discard

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
proc treeReprImpl[K,V](t: RBTree[K,V], tab: int): string =
  result = mkTab(tab, TAB_STEP)
  if t.isLeaf:
    result.add("[NIL]\n")
  else:
    when V is NonVoid:
      result.add("[" & $t.k & ", " & $t.v & "]\n")
    else:
      result.add("[" & $t.k & "]\n")
    result.add(treeReprImpl(t.l, tab + TAB_STEP))
    result.add(treeReprImpl(t.r, tab + TAB_STEP))
    
proc treeRepr*(t: RBTree): string =
  result = treeReprImpl(t, 0)
  result.setLen(result.len - 1)

proc `$`*(n: RBTree): string = n.treeRepr
  

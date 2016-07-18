import boost.typeclasses, boost.types

####################################################################################################
# Type

type
  Color = enum BLACK, RED 
  RBTree*[K,V] = ref RBTreeObj[K,V] not nil
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
proc isLeaf*(t: RBTree): bool {.inline.} = t.isEmpty
proc isBranch*(t: RBTree): bool {.inline.} = not t.isEmpty
proc isRed(t: RBTree): bool {.inline.} = t.color == RED
proc isBlack(t: RBTree): bool {.inline.} = t.color == BLACK

proc value[K;V: NonVoid](t: RBTree[K,V]): V {.inline.} =
  assert t.isBranch, "Can't get value of leaf"
  when V is Unit:
    ()
  else:
    t.v

proc len*(t: RBTree): int =
  if t.isLeaf:
    0
  else:
    len(t.l) + 1 + len(t.r)

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
  result = newRBTree(BLACK, result.l, result.k, result.value, result.r)

proc add*[K](t: RBTree[K,void], k: K): RBTree[K,void] =
  # RBTree[K,Unit] and RBTree[K,void] have the same
  # memory layout. So we use cast here
  cast[RBTree[K,void]](add(cast[RBTree[K,Unit]](t), k, ()))

proc findNode[K,V](t: RBTree[K,V], k: K): RBTree[K,V] =
  if t.isLeaf or t.k == k:
    t
  elif t.k < k:
    t.r.findNode(k)
  else:
    t.l.findNode(k)

proc hasKey*[K,V](t: RBTree[K,V], k: K): bool =
  not t.findNode(k).isLeaf

proc getOrDefault*[K;V: NonVoid](t: RBTree[K,V], k: K): V =
  let res = t.findNode(k)
  if res.isBranch:
    result = res.value

proc blackToRed[K,V](t: RBTree[K,V]): RBTree[K,V] =
  assert(t.isBlack and t.isBranch, "Invariance violation")
  result = newRBTree(RED, t.l, t.k, t.value, t.r)

proc balanceLeft[K,V](a: RBTree[K,V], k: K, v: V, b: RBTree[K,V]): RBTree[K,V] =
  if a.isRed:
    result = newRBTree(RED, newRBTree(BLACK, a.l, a.k, a.value, a.r), k, v, b)
  elif b.isBlack and b.isBranch:
    result = balance(a, k, v, b.blackToRed)
  elif b.isRed and b.l.isBlack and b.l.isBranch:
    result = newRBTree(RED, newRBTree(BLACK, a, k, v, b.l.l), b.l.k, b.l.value, balance(b.l.r, b.k, b.value, b.r.blackToRed))
  else:
    assert false

proc balanceRight[K,V](a: RBTree[K,V], k: K, v: V, b: RBTree[K,V]): RBTree[K,V] =
  if b.isRed:
    result = newRBTree(RED, a, k, v, newRBTree(BLACK, b.l, b.k, b.value, b.r))
  elif a.isBlack and a.isBranch:
    result = balance(a.blackToRed, k, v, b)
  elif a.isRed and a.r.isBlack and a.r.isBranch:
    result = newRBTree(RED, balance(a.l.blackToRed, a.k, a.value, a.r.l), a.r.k, a.r.value, newRBTree(BLACK, a.r.r, k, v, b))
  else:
    assert false

proc app[K,V](a, b: RBTree[K,V]): RBTree[K,V] =
  if a.isEmpty:
    result = b
  elif b.isEmpty:
    result = a
  elif a.isRed and b.isRed:
    let ar = a.r.app(b.l)
    if ar.isRed:
      result = newRBTree(RED, newRBTree(RED, a.l, a.k, a.value, ar.l), ar.k, ar.value, newRBTree(RED, ar.r, b.k, b.value, b.r))
    else:
      result = newRBTree(RED, a.l, a.k, a.value, newRBTree(RED, ar, b.k, b.value, b.r))
  elif a.isBlack and b.isBlack:
    let ar = a.r.app(b.l)
    if ar.isRed:
      result = newRBTree(RED, newRBTree(BLACK, a.l, a.k, a.value, ar.l), ar.k, ar.value, newRBTree(BLACK, ar.r, b.k, b.value, b.r))
    else:
      result = balanceLeft(a.l, a.k, a.value, newRBTree(BLACK, ar, b.k, b.value, b.r))
  elif b.isRed:
    result = newRBTree(RED, app(a, b.l), b.k, b.value, b.r)
  elif a.isRed:
    result = newRBTree(RED, a.l, a.k, a.value, app(a.r, b))
  else:
    assert false

proc del*[K;V: NonVoid](t: RBTree[K,V], k: K): RBTree[K,V] =
  proc del(t: RBTree[K,V]): RBTree[K,V]
  proc delformLeft(a: RBTree[K,V], k: K, v: V, b: RBTree[K,V]): RBTree[K,V] =
    if a.isBlack and a.isBranch:
      balanceLeft(del(a), k, v, b)
    else:
      newRBTree(RED, del(a), k, v, b)
  proc delformRight(a: RBTree[K,V], k: K, v: V, b: RBTree[K,V]): RBTree[K,V] =
    if b.isBlack and b.isBranch:
      balanceRight(a, k, v, del(b))
    else:
      newRBTree(RED, a, k, v, del(b))
  proc del(t: RBTree[K,V]): RBTree[K,V] =
    if t.isEmpty:
      result = t
    elif k < t.k:
      result = delformLeft(t.l, t.k, t.value, t.r)
    elif k > t.k:
      result = delformRight(t.l, t.k, t.value, t.r)
    else:
      result = t.l.app(t.r)

  result = del(t)
  if result.isBranch:
    result = newRBTree(BLACK, result.l, result.k, result.value, result.r)

proc del*[K](t: RBTree[K,void], k: K): RBTree[K,void] =
  # Same assumptions as in void version of `add`
  cast[RBTree[K,void]](del(cast[RBTree[K,Unit]](t), k))

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
  

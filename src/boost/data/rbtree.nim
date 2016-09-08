import boost.typeclasses, boost.types, boost.data.stackm

#[
# Type
]#

{.warning[SmallLshouldNotBeUsed]: off.}

type
  Color = enum BLACK, RED
  Node[K,V] = ref NodeObj[K,V]
  NodeObj[K,V] = object
    case e: bool
    of true:
      discard
    else:
      k: K
      c: Color
      l,r: Node[K,V]
      when V isnot void and V isnot Unit:
        v: V
  RBTree*[K,V] = ref RBTreeObj[K,V]
  RBTreeObj[K,V] = object
    root: Node[K,V]
    length: int

proc newNode[K,V](): Node[K,V] =
  Node[K,V](e: true)

proc newNode[K](c: Color, l: Node[K,Unit], k: K, v: Unit, r: Node[K,Unit]): Node[K,Unit] {.inline.} =
  Node[K,Unit](k: k, c: c, l: l, r: r)
proc newNode[K;V: NonVoid](c: Color, l: Node[K,V], k: K, v: V, r: Node[K,V]): Node[K,V] {.inline.} =
  Node[K,V](k: k, v: v, c: c, l: l, r: r)
proc newNode[K](c: Color, l: Node[K,void], k: K, r: Node[K,void]): Node[K,void] {.inline.} =
  Node[K,void](k: k, c: c, l: l, r: r)

proc newRBTree*[K;V: NonVoid](): RBTree[K,V] =
  RBTree[K,V](root: newNode[K,V](), length: 0)

proc newRBSet*[K](): RBTree[K,void] =
  RBTree[K,void](root: newNode[K,void](), length: 0)

proc newRBTree[K,V](root: Node[K,V], length: int): RBTree[K,V] =
  RBTree[K,V](root: root, length: length)

proc color(t: Node): Color {.inline.} =
  case t.e
  of true:
    BLACK
  else:
    t.c

proc isEmpty(t: Node): bool {.inline.} = t.e
proc isLeaf(t: Node): bool {.inline.} = t.isEmpty
proc isBranch(t: Node): bool {.inline.} = not t.isEmpty
proc isEmpty*(t: RBTree): bool {.inline.} = t.root.isEmpty
proc isLeaf*(t: RBTree): bool {.inline.} = t.root.isEmpty
proc isBranch*(t: RBTree): bool {.inline.} = not t.root.isEmpty
proc isRed(t: Node): bool {.inline.} = (t.color == RED)
proc isBlack(t: Node): bool {.inline.} = (t.color == BLACK)

proc value[K;V: NonVoid](t: Node[K,V]): V {.inline.} =
  assert t.isBranch, "Can't get value of leaf"
  when V is Unit:
    ()
  else:
    t.v

proc len*(t: RBTree): int =
  t.length

proc balance[K,V](a: Node[K,V], k: K, v: V, b: Node[K,V]): Node[K,V] {.inline.} =
  if a.isRed and b.isRed:
    result = newNode(RED, newNode(BLACK, a.l, a.k, a.value, a.r), k, v, newNode(BLACK, b.l, b.k, b.value, b.r))
  elif a.isRed and a.l.isRed:
    result = newNode(RED, newNode(BLACK, a.l.l, a.l.k, a.l.value, a.l.r), a.k, a.value, newNode(BLACK, a.r, k, v, b))
  elif a.isRed and a.r.isRed:
    result = newNode(RED, newNode(BLACK, a.l, a.k, a.value, a.r.l), a.r.k, a.r.value, newNode(BLACK, a.r.r, k, v, b))
  elif b.isRed and b.r.isRed:
    result = newNode(RED, newNode(BLACK, a, k, v, b.l), b.k, b.value, newNode(BLACK, b.r.l, b.r.k, b.r.value, b.r.r))
  elif b.isRed and b.l.isRed:
    result = newNode(RED, newNode(BLACK, a, k, v, b.l.l), b.l.k, b.l.value, newNode(BLACK, b.l.r, b.k, b.value, b.r))
  else:
    result = newNode(BLACK, a, k, v, b)

proc add[K;V: NonVoid](t: Node[K,V], k: K, v: V): (Node[K,V], bool) =
  var ok = false
  proc ins(t: Node[K,V], ok: var bool): Node[K,V] =
    if t.isEmpty:
      ok = true
      result = newNode(RED, newNode[K,V](), k, v, newNode[K,V]())
    elif t.isBlack:
      if k < t.k:
        result = balance(ins(t.l, ok), t.k, t.value, t.r)
      elif k > t.k:
        result = balance(t.l, t.k, t.value, ins(t.r, ok))
      else:
        ok = true
        result = newNode(BLACK, t.l, k, v, t.r)
    else:
      if k < t.k:
        result = newNode(RED, ins(t.l, ok), t.k, t.value, t.r)
      elif k > t.k:
        result = newNode(RED, t.l, t.k, t.value, ins(t.r, ok))
      else:
        ok = true
        result = newNode(RED, t.l, k, v, t.r)
  let res = ins(t, ok)
  if ok:
    result = (newNode(BLACK, res.l, res.k, res.value, res.r), ok)
  else:
    result = (t, ok)

proc add*[K;V: NonVoid](t: RBTree[K,V], k: K, v: V): RBTree[K,V] =
  let res = add(t.root, k, v)
  if not res[1]:
    result = t
  else:
    result = newRBTree(res[0], t.length + 1)

proc add*[K](t: RBTree[K,void], k: K): RBTree[K,void] =
  # RBTree[K,Unit] and RBTree[K,void] have the same
  # memory layout. So we use cast here
  cast[RBTree[K,void]](add(cast[RBTree[K,Unit]](t), k, ()))

proc mkRBTree*[K;V: NonVoid](arr: openarray[(K,V)]): RBTree[K,V] =
  result = newRBTree[K,V]()
  for el in arr:
    result = result.add(el[0], el[1])

proc mkRBSet*[K](arr: openarray[K]): RBTree[K,void] =
  result = newRBSet[K]()
  for el in arr:
    result = result.add(el)

proc findNode[K,V](t: Node[K,V], k: K): Node[K,V] =
  if t.isLeaf or t.k == k:
    t
  elif t.k < k:
    t.r.findNode(k)
  else:
    t.l.findNode(k)

proc hasKey[K,V](t: Node[K,V], k: K): bool =
  not t.findNode(k).isLeaf

proc hasKey*[K,V](t: RBTree[K,V], k: K): bool =
  t.root.hasKey(k)

proc getOrDefault[K;V: NonVoid](t: Node[K,V], k: K): V =
  let res = t.findNode(k)
  if res.isBranch:
    result = res.value

proc getOrDefault*[K;V: NonVoid](t: RBTree[K,V], k: K): V =
  t.root.getOrDefault(k)

proc maybeGet*[K;V: NonVoid](t: RBTree[K,V], k: K, v: var V): bool =
  let res = t.root.findNode(k)
  result = res.isBranch
  if result:
    v = res.value

proc blackToRed[K,V](t: Node[K,V]): Node[K,V] =
  assert(t.isBlack and t.isBranch, "Invariance violation")
  result = newNode(RED, t.l, t.k, t.value, t.r)

proc balanceLeft[K,V](a: Node[K,V], k: K, v: V, b: Node[K,V]): Node[K,V] =
  if a.isRed:
    result = newNode(RED, newNode(BLACK, a.l, a.k, a.value, a.r), k, v, b)
  elif b.isBlack and b.isBranch:
    result = balance(a, k, v, b.blackToRed)
  elif b.isRed and b.l.isBlack and b.l.isBranch:
    result = newNode(RED, newNode(BLACK, a, k, v, b.l.l), b.l.k, b.l.value, balance(b.l.r, b.k, b.value, b.r.blackToRed))
  else:
    doAssert false
    new result # Disable ProveInit warning

proc balanceRight[K,V](a: Node[K,V], k: K, v: V, b: Node[K,V]): Node[K,V] =
  if b.isRed:
    result = newNode(RED, a, k, v, newNode(BLACK, b.l, b.k, b.value, b.r))
  elif a.isBlack and a.isBranch:
    result = balance(a.blackToRed, k, v, b)
  elif a.isRed and a.r.isBlack and a.r.isBranch:
    result = newNode(RED, balance(a.l.blackToRed, a.k, a.value, a.r.l), a.r.k, a.r.value, newNode(BLACK, a.r.r, k, v, b))
  else:
    doAssert false
    new result # Disable ProveInit warning

proc app[K,V](a, b: Node[K,V]): Node[K,V] =
  if a.isEmpty:
    result = b
  elif b.isEmpty:
    result = a
  elif a.isRed and b.isRed:
    let ar = a.r.app(b.l)
    if ar.isRed:
      result = newNode(RED, newNode(RED, a.l, a.k, a.value, ar.l), ar.k, ar.value, newNode(RED, ar.r, b.k, b.value, b.r))
    else:
      result = newNode(RED, a.l, a.k, a.value, newNode(RED, ar, b.k, b.value, b.r))
  elif a.isBlack and b.isBlack:
    let ar = a.r.app(b.l)
    if ar.isRed:
      result = newNode(RED, newNode(BLACK, a.l, a.k, a.value, ar.l), ar.k, ar.value, newNode(BLACK, ar.r, b.k, b.value, b.r))
    else:
      result = balanceLeft(a.l, a.k, a.value, newNode(BLACK, ar, b.k, b.value, b.r))
  elif b.isRed:
    result = newNode(RED, app(a, b.l), b.k, b.value, b.r)
  elif a.isRed:
    result = newNode(RED, a.l, a.k, a.value, app(a.r, b))
  else:
    doAssert false
    new result # Disable ProveInit warning

proc del[K;V: NonVoid](t: Node[K,V], k: K): (Node[K,V], bool) =
  var ok = false
  proc del(t: Node[K,V], ok: var bool): Node[K,V]
  proc delformLeft(a: Node[K,V], k: K, v: V, b: Node[K,V]): Node[K,V] =
    if a.isBlack and a.isBranch:
      balanceLeft(del(a, ok), k, v, b)
    else:
      newNode(RED, del(a, ok), k, v, b)
  proc delformRight(a: Node[K,V], k: K, v: V, b: Node[K,V]): Node[K,V] =
    if b.isBlack and b.isBranch:
      balanceRight(a, k, v, del(b, ok))
    else:
      newNode(RED, a, k, v, del(b, ok))
  proc del(t: Node[K,V], ok: var bool): Node[K,V] =
    if t.isEmpty:
      result = t
    elif k < t.k:
      result = delformLeft(t.l, t.k, t.value, t.r)
    elif k > t.k:
      result = delformRight(t.l, t.k, t.value, t.r)
    else:
      ok = true
      result = t.l.app(t.r)

  let res = del(t, ok)
  result = ((if res.isLeaf: res else: newNode(BLACK, res.l, res.k, res.value, res.r)), ok)

proc del*[K;V: NonVoid](t: RBTree[K,V], k: K): RBTree[K,V] =
  let res = del(t.root, k)
  if res[1]:
    result = newRBtree(res[0], t.length - 1)
  else:
    result = t

proc del*[K](t: RBTree[K,void], k: K): RBTree[K,void] =
  # Same assumptions as in void version of `add`
  cast[RBTree[K,void]](del(cast[RBTree[K,Unit]](t), k))

template iterateNode(n: typed, next: untyped, op: untyped): untyped =
  var s = newStackM[type(n)]()
  var root = n
  while root.isBranch:
    push(s, root)
    root = root.l
  while not s.isEmpty:
    var next = s.pop
    root = next.r
    while root.isBranch:
      push(s, root)
      root = root.l
    `op`

include impl/nodeiterator

iterator items*[K,V](t: RBTree[K,V]): K =
  iterateNode(t.root, next):
    yield next.k

iterator keys*(t: RBTree): auto =
  iterateNode(t.root, next):
    yield next.k

iterator pairs*[K;V: NonVoid](t: RBTree[K,V]): (K,V) =
  iterateNode(t.root, next):
    yield (next.k, next.v)

iterator values*(t: RBTree): auto =
  iterateNode(t.root, next):
    yield next.value

proc equals*[K;V: NonVoid](l, r: RBTree[K,V]): bool =
  equalsImpl(l, r)

proc `==`*[K;V: NonVoid](l, r: RBTree[K,V]): bool =
  l.equals(r)

proc equals*[K](l, r: RBTree[K,void]): bool =
  equalsImpl(l, r)

proc `==`*[K](l, r: RBTree[K,void]): bool =
  l.equals(r)

#[
# Pretty print
]#

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
proc treeReprImpl[K,V](t: Node[K,V], tab: int): string =
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
  result = treeReprImpl(t.root, 0)
  result.setLen(result.len - 1)

proc `$`*(n: RBTree): string = n.treeRepr

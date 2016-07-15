import boost.typeclasses

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
      when V isnot void:
        v: V
      l,r: RBTree[K,V]

proc newRBtree*[K,V](): RBTree[K,V] =
  RBTree[K,V](e: true)

proc newRBTree[K,V: NonVoid](k: K, v: V, c: Color, l: RBTree[K,V], r: RBTree[K,V]): RBTree[K,V] =
  RBTree[K,V](k: k, v: v, c: c, l: l, r: r)
proc newRBTree[K](k: K, c: Color, l: RBTree[K,void], r: RBTree[K,void]): RBTree[K,void] =
  RBTree[K,void](k: k, c: c, l: l, r: r)

proc isEmpty*(t: RBTree): bool = t.e

proc color(t: RBTree): Color =
  case t.e
  of true:
    BLACK
  else:
    t.c

proc add*[K,V: NonVoid](t: RBTree[K,V], k: K, v: V): RBTree[K,V] = discard
proc add*[K](t: RBTree[K,void], k: K): RBTree[K,void] = discard
proc del*[K,V](t: RBTree[K,V], k: K): RBTree[K,V] = discard
proc hasKey*[K,V](t: RBTree[K,V], k: K): bool = discard
proc getOrDefault*[K,V: NonVoid](t: RBTree[K,V], k: K): V = discard

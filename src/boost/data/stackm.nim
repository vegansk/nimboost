type
  StackM*[T] = ref StackObj[T]
  Node[T] = ref NodeObj[T]
  NodeObj[T] = object
    v: T
    p: Node[T]
  StackObj[T] = object
    stack: Node[T]
    length: int

proc newStackM*[T](): StackM[T] =
  StackM[T](stack: nil, length: 0)

proc newNode[T](v: T, p: Node[T]): Node[T] =
  Node[T](v: v, p: p)

proc len*(s: StackM): int =
  s.length

proc isEmpty*(s: StackM): bool =
  s.length == 0

proc push*[T](s: var StackM[T], v: T) =
  s.stack = newNode(v, s.stack)
  inc s.length

proc pop*[T](s: var StackM[T]): T =
  assert s.length > 0
  result = s.stack.v
  s.stack = s.stack.p
  dec s.length

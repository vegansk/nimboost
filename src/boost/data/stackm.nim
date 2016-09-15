## Mutable stack object implementation.

type
  StackM*[T] = ref StackObj[T]
    ## The mutable stack.
  Node[T] = ref NodeObj[T]
  NodeObj[T] = object
    v: T
    p: Node[T]
  StackObj[T] = object
    stack: Node[T]
    length: int

proc newStackM*[T](): StackM[T] =
  ## Creates new stack object.
  StackM[T](stack: nil, length: 0)

proc newNode[T](v: T, p: Node[T]): Node[T] =
  Node[T](v: v, p: p)

proc len*(s: StackM): int =
  ## Returns the length of the stack.
  s.length

proc isEmpty*(s: StackM): bool =
  ## Checks if the stack is empty.
  s.length == 0

proc push*[T](s: var StackM[T], v: T) =
  ## Pushes the value ``v`` onto the top of the stack ``s``.
  s.stack = newNode(v, s.stack)
  inc s.length

proc pop*[T](s: var StackM[T]): T =
  ## Pops the value from the top of the stack ``s``.
  ## Throws an exception if the stack is empty.
  doAssert s.length > 0
  result = s.stack.v
  s.stack = s.stack.p
  dec s.length

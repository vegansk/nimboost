import unittest, boost.typeclasses, typetraits

# Needed for the ``check`` macro pretty print
proc `$`(t: typedesc): auto = t.name

type
  TestObj = object
    i: int
    s: string

suite "Typeclasses":
  test "NonVoid":
    check: void isnot NonVoid
    check: int is NonVoid

  test "Eq":
    check: int is Eq
    check: string is Eq
    check: float is Eq
    let a = (1, 'a')
    check: a is Eq
    let b = @[1,2,3]
    check: b is Eq
    check: TestObj is Eq # Objects is Eq by default

  test "Ord":
    check: int is Ord
    check: string is Ord
    check: float is Ord
    
    let a = (1, 'a')
    check: a is Ord

    let b = @[1,2,3]
    check: b isnot Ord # Sequences is not Ord by default
    proc `<`[T:Ord](s1, s2: seq[T]): bool =
      let l = min(s1.len, s2.len)
      for i in 0..<l:
        if s1[i] >= s2[i]:
          return false
      return s1.len < s2.len
    proc `<=`[T:Ord](s1, s2: seq[T]): bool =
      s1 < s2 or s1 == s2
    check: b is Ord # But we can make them Ord

    check: TestObj isnot Ord # Objects can be compared by theirs fields values

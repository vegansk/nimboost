import boost.typeutils,
       unittest,
       macros,
       ./test_typeutils_int

suite "typeutils - constructor":
  test "simple object":
    type
      X1 = object
        a: int
        b: seq[string]
    check: compiles(X1.genConstructor)
    when compiles(X1.genConstructor):
      genConstructor X1
      check: declared(initX1)
      when declared(initX1):
        let x1 = initX1(1, @["2"])
        check: x1.a == 1
        check: x1.b == @["2"]

    type
      X2 = ref object
        a: int
        b: seq[string]
    check: compiles(X2.genConstructor)
    when compiles(X2.genConstructor):
      genConstructor X2
      check: declared(newX2)
      when declared(newX2):
        let x2 = newX2(1, @["2"])
        check: x2.a == 1
        check: x2.b == @["2"]

  test "exported object":
    check: declared(createGlobalX)
    when declared(createGlobalX):
      let x3 = createGlobalX(1, @["2"])
      check: x3.a == 1
      check: x3.b == @["2"]

  test "generic fields":
    type A[T] = object
        x: T

    check: compiles(A.genConstructor)
    when compiles(A.genConstructor):
      genConstructor A
      check: declared(initA)
      when declared(initA):
        let a = initA(1)
        check: a.x == 1

    type B[T] = ref object
      x: T

    check: compiles(B.genConstructor)
    when compiles(B.genConstructor):
      genConstructor B
      check: declared(newB)
      when declared(newB):
        let b = newB(1)
        check: b.x == 1

  test "ref object":
    type XObj = object
      x: int
    type X = ref XObj
    check: compiles(X.genConstructor)
    when compiles(X.genConstructor):
      genConstructor X
      check: declared(newX)
      when declared(newX):
        let x = newX(1)
        check: x.x == 1

    type YObj[T,U] = object
      y1: T
      y2: U
    type Y[T] = ref YObj[T, int]
    check: compiles(Y.genConstructor)
    when compiles(Y.genConstructor):
      genConstructor Y
      check: declared(newY)
      when declared(newY):
        let y = newY(1, 2)
        check: y.y1 == 1
        check: y.y2 == 2

  test "complex fields":
    type A = object
      x: int
    type B = object
      a: A

    check: compiles(B.genConstructor)
    when compiles(B.genConstructor):
      genConstructor B
      check: declared(initB)
      when declared(initB):
        let b = initB(A(x: 1))
        check: b.a.x == 1

    type C[D] = object
        x: D
    type E = object
        c: C[int]

    check: compiles(E.genConstructor)
    when compiles(E.genConstructor):
      genConstructor E
      check: declared(initE)
      when declared(initE):
        let e = initE(C[int](x: 1))
        check: e.c.x == 1

suite "typeutils - data keyword":
  data A:
    a: int
    let b = "a"
    var c: seq[int] = @[1,2,3]
  test "simple type":
    check compiles(initA)
    when compiles(initA):
      let a = initA(1, c = @[1,2])
      check a.a == 1 and a.b == "a" and a.c == @[1,2]

  data B of A:
    d = "d"
  test "simple types inheritance":
    check compiles(initB)
    when compiles(initB):
      let b = initB(1)
      check b.a == 1 and b.b == "a" and b.c == @[1,2,3] and b.d == "d"

  data ARef ref object:
    a: int
    let b = "a"
    var c: seq[int] = @[1,2,3]
  test "reference type":
    check compiles(newARef)
    when compiles(newARef):
      let a = newARef(1, c = @[1,2])
      check a.a == 1 and a.b == "a" and a.c == @[1,2]

  data BRef ref object of ARef:
    d: string
  test "reference types inheritance":
    check compiles(newBRef)
    when compiles(newBRef):
      let b = newBRef(1, d = "d")
      check b.a == 1 and b.b == "a" and b.c == @[1,2,3] and b.d == "d"

  test "export types":
    check compiles(GlobalData)
    when compiles(GlobalData):
      check initGlobalData(1).a == 1
    check compiles(GlobalDataRef)
    when compiles(GlobalDataRef):
      check newGlobalDataRef(1).a == 1

  test "full qualified parent type name":
    const isValid = compiles((block:
      data GlobalDataChild of test_typeutils_int.GlobalData:
        b: string
    ))
    check isValid
    when isValid:
      data GlobalDataChild of test_typeutils_int.GlobalData:
        b: string
      let d = initGlobalDataChild(1, "a")
      check d.a == 1 and d.b == "a"
    const isValidRef = compiles((block:
      data GlobalDataRefChild ref object of test_typeutils_int.GlobalDataRef:
        b: string
    ))
    check isValidRef
    when isValidRef:
      data GlobalDataRefChild ref object of test_typeutils_int.GlobalDataRef:
        b: string
      let dRef = newGlobalDataRefChild(1, "a")
      check dRef.a == 1 and dRef.b == "a"

  test "[im]mutability":
    data Obj:
      a: int     # Immutable, same as let a: int
      let b: int # Immutable
      var c: int # Mutable
    var x = initObj(1,2,3)
    check x.a == 1 and x.b == 2 and x.c == 3
    check: not compiles((block: x.a = 10))
    check: not compiles((block: x.b = 10))
    check compiles((block: x.c = 10))

  test "generics":
    const isValidSimple = compiles((
      block:
        data Obj1[T,U]:
          x: T
          var y: U
    ))
    check isValidSimple
    when isValidSimple:
      data Obj1[T,U]:
        x: T
        var y: U
      let a = initObj1(1, "a")
      check a.x == 1 and a.y == "a"

    const isValidWithParent = compiles((
      block:
        data Obj2[T,U,V] of Obj1[T,U]:
          z: V
    ))
    check isValidWithParent
    when isValidWithParent:
      data Obj2[T,U,V] of Obj1[T,U]:
        let z: V
      let b = initObj2(1, "a", 'a')
      check b.x == 1 and b.y == "a" and b.z == 'a'

    const isValidWithNonGenericParent = compiles((
      block:
        data Obj3:
          x: int
        data Obj4[T] of Obj3:
          y: T
    ))
    check isValidWithNonGenericParent
    when isValidWithNonGenericParent:
      data Obj3:
        x: int
      data Obj4[T] of Obj3:
        y: T
      let c = initObj4(1, "a")
      check c.x == 1 and c.y == "a"

  test "from example":
    data TypeA:
      a = 1
      var b = "a"

    var x = initTypeA(b = "b")
    assert x.a == 1
    assert x.b == "b"
    x.b = "a"
    check: not compiles((block:
      x.a = 2
    ))

    data TypeB[C,D] of TypeA:
      c: C
      var d: D
    var y = initTypeB(100, "aaa", 'a', 1.0)

    data TypeC ref object of TypeA:
      c: char

    var z = newTypeC(c = 'a')
    z.b = "b"

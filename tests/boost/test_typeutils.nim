import boost.typeutils,
       boost.jsonserialize,
       unittest,
       macros,
       ./test_typeutils_int,
       patty,
       json

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

    const isValidRef = compiles((
      block:
        data Obj5[T] ref object:
          x: T
    ))
    check: isValidRef
    when isValidRef:
      data Obj5[T] ref object:
        x: T
      let d = newObj5(1)
      check: d.x == 1
    const isValidRefWithParent = compiles((
      block:
        data Obj5[T] ref object:
          x: T
        data Obj6[T,U] ref object of Obj5[T]:
          y: U
    ))
    check: isValidRefWithParent
    when isValidRefWithParent:
      data Obj6[T,U] ref object of Obj5[T]:
        y: U
      let e = newObj6(1, "a")
      check: e.x == 1 and e.y == "a"

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
    discard initTypeB(100, "aaa", 'a', 1.0)

    data TypeC ref object of TypeA:
      c: char

    var z = newTypeC(c = 'a')
    z.b = "b"

  when not defined(js):
    # See https://github.com/nim-lang/Nim/issues/5517
    test "show typeclass":
      data TypeA1, show:
        a: int
        b: string
        let c: pointer = nil
      let x = initTypeA1(1, "a")
      check: compiles($x)
      when compiles($x):
        check: $x == "TypeA1(a: 1, b: a, c: ...)"

  test "copy macro":
    data Imm, copy:
      a: int
      b: string
      c = 'c'
    let x = initImm(1, "b")
    check: compiles(x.copyImm(a = 2))
    when compiles(x.copyImm(a = 2)):
      let y = x.copyImm(a = 2)
      check: y.a == 2 and y.b == "b" and y.c == 'c'

    check: compiles(newGlobalDataRef(1).copyGlobalDataRef(a = 2))
    when compiles(newGlobalDataRef(1).copyGlobalDataRef(a = 2)):
      check: newGlobalDataRef(1).copyGlobalDataRef(a = 2).a == 2

  test "Reserved words in type definition":
    data RWTest:
      `type`: string
      `for` =  "b"
      let `let`: string = "let"
      var `var`: string
      var `yield`: string = "yield"
    let x = initRWTest(`type` = "type", `var` = "var", `for` = "for", `let` = "let", `yield` = "yield")
    check: x.`type` == "type"
    check: x.`var` == "var"
    check: x.`for` == "for"
    check: x.`let` == "let"
    check: x.`yield` == "yield"

  test "Modifiers":
    check: declared(TestModifiers)
    check: not declared(testModifiers)
    check: not compiles((
      block:
        var tmv: TestModifiers
        discard tmv.a
    ))
    check: not compiles((
      block:
        var tmv: TestModifiers
        discard tmv.copyTestModifiers(a = 1)
    ))
    #TODO: It works because of standard `$` implementation
    # check: not compiles((
    #   block:
    #     var tmv: TestModifiers
    #     discard tmv.`$`
    # ))

  test "Sequences support":
    data TypeWithSeq, show:
      a: seq[int]
      b = @["a"]

    let x = initTypeWithSeq(@[1])
    check: x.a == @[1] and x.b == @["a"]

    data RefTypeWithSeq ref object, show:
      let a: seq[int] = @[]
      let b: seq[string] = @[]

    let y = newRefTypeWithSeq(@[1])
    check: y.a == @[1] and y.b == @[]

  test "ADT":
    data ADT1, show, copy:
      Branch1:
        a: int
      Branch2:
        b: string
        c = 123
    let x1 = initBranch1(100).copyBranch1(a = 10)
    check: x1.a == 10
    let y1 = initBranch2("test").copyBranch2(c = 1000)
    check: y1.b == "test" and y1.c == 1000

    data ADT2 ref object, show, copy:
      a: int
      Branch3:
        b = "b"
      Branch4:
        c = 'c'
    let x2 = newBranch3(10).copyBranch3(b = "bbb")
    check: x2.a == 10 and x2.b == "bbb"
    let y2 = newBranch4(10).copyBranch4(a = 100)
    check: y2.a == 100 and y2.c == 'c'

  test "Patty compatibility":
    data Shape, show, copy:
      Circle:
        r: float
      Rectangle:
        w: float
        h: float

    match initCircle(10.0):
      Circle(r):
        check: r == 10.0
      Rectangle:
        check: false

  test "Eq typeclass":
    data Test[T], eq:
      a: T
      b = "b"
    check: initTest(1) == initTest(1, "b")
    check: initTest(1) != initTest(1, "a")

    data TestAdt, eq:
      Br1:
        a: int
      Br2:
        b: string
    check: initBr2("a") == initBr2("a")
    check: initBr2("a") != initBr1(1)

  test "Json typeclass":
    data Test[T], json:
      a: T
      b: int

    let x1 = fromJson(Test[string], parseJson"""{ "a": "a", "b": 1 }""")
    check: x1.a == "a" and x1.b == 1
    expect(FieldException):
      discard fromJson(Test[string], parseJson"""{ "A": "a", "B": 1 }""")

    data TestAdt, json:
      Br1:
        a: int
      Br2:
        b: string

    let x2 = TestAdt.fromJson(parseJson("""{"kind": "Br1", "a": 1}"""))
    check: x2.a == 1
    expect(FieldException):
      discard fromJson(TestAdt, parseJson"""{ "A": "a", "B": 1 }""")

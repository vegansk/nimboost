import boost.objutils,
       unittest,
       macros

type GlobalX* = object
  a: int
  b: seq[string]

when compiles(GlobalX.genConstructor):
  GlobalX.genConstructor createGlobalX, exported

suite "objutils":
  test "constructor":
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

    check: declared(createGlobalX)
    when declared(createGlobalX):
      let x3 = createGlobalX(1, @["2"])
      check: x3.a == 1
      check: x3.b == @["2"]

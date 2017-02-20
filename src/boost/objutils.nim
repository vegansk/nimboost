import macros

proc generateConstructor(typ: NimNode, n: string, exported: bool): NimNode =
  expectLen typ.getType, 2
  let t = typ.getType[1]
  let (obj, isRef) = if t.typeKind == ntyObject:
                       (t.getType, false)
                     elif t.typeKind == ntyRef:
                       (t.getType[1].getType, true)
                     else:
                       (error("Unexpected type kind " & $t.typeKind); (nil, false))
  expectLen obj, 3
  let recList = obj[2]
  expectKind recList, nnkRecList

  let name = if n != "": n else: if isRef: "new" & $typ else: "init" & $typ
  let nameI = if exported: postfix(ident(name), "*") else: ident(name)

  var params = newSeq[NimNode]()
  params.add(typ)
  for field in recList:
    params.add(newIdentDefs(ident($field), field.getType))

  let body = newStmtList()
  if isRef:
    body.add newCall(ident"new", ident"result")
  for field in recList:
    let i = ident($field)
    body.add newAssignment(newDotExpr(ident"result", i), i)

  result = newProc(nameI, params, body)

macro genConstructor*(t: typed, args: varargs[untyped]): untyped =
  if args.len > 2:
    error("Wrong parameters for constructor generator call")
  let exported = if args.len == 0: false else: $(args[^1]) == "exported"
  if args.len == 2 and not exported:
    error("Wrong parameters for constructor generator call")
  let name = case args.len
             of 0: ""
             else:
               if args.len == 1 and exported: "" else: $args[0]
  result = generateConstructor(t, name, exported)

import macros

proc generateConstructor(`type`: NimNode, n: string, exported: bool): NimNode =
  expectLen `type`.getType, 2
  let t = `type`.getType[1]
  let (obj, isRef) = if t.typeKind == ntyObject:
                       (t.getType, false)
                     elif t.typeKind == ntyRef:
                       (t.getType[1].getType, true)
                     else:
                       (error("Unexpected type kind " & $t.typeKind); (nil, false))
  expectLen obj, 3
  let recList = obj[2]
  expectKind recList, nnkRecList

  let name = if n != "": n else: if isRef: "new" & $`type` else: "init" & $`type`
  let nameI = if exported: postfix(ident(name), "*") else: ident(name)

  var params = newSeq[NimNode]()
  params.add(`type`)
  for field in recList:
    params.add(newIdentDefs(ident($field), field.getType))

  let body = newStmtList()
  if isRef:
    body.add newCall(ident"new", ident"result")
  for field in recList:
    let i = ident($field)
    body.add newAssignment(newDotExpr(ident"result", i), i)

  result = newProc(nameI, params, body)

macro genConstructor*(`type`: typed, args: varargs[untyped]): untyped =
  ## Generates constructor for the `type`. The second optional parameter
  ## is the name of the constructor. By default it's ``newType`` for
  ## the ref objects and ``initType`` for the objects. The third optional
  ## parameter is the word ``exported`` and means that the constructor
  ## must be exported.
  ##
  ## Example:
  ## .. code-block:: nim
  ##
  ##   type Obj* = ref object
  ##     x: int
  ##     y: string
  ##   genConstructor Obj, exported
  ##
  ##   let x = newObj(1, "a")
  if args.len > 2:
    error("Wrong parameters for constructor generator call")
  let exported = if args.len == 0: false else: $(args[^1]) == "exported"
  if args.len == 2 and not exported:
    error("Wrong parameters for constructor generator call")
  let name = case args.len
             of 0: ""
             else:
               if args.len == 1 and exported: "" else: $args[0]
  result = generateConstructor(`type`, name, exported)

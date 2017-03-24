## Provides miscellaneous utilities working with types: types declaration,
## constructor generation, etc.
##
## The ``data`` keyword
## --------------------
##
## Keyword ``data`` allows to create new value and reference object types. Also,
## it generates constructors that is more safe to use then standard one, because
## they allows optional fields only when explicit default value is set.
##
## Let's define some object:
##
## .. code-block:: nim
##   data TypeA:
##     a = 1
##     var b = "a"
##
## The object type ``TypeA`` has immutable field ``a`` of type int with default value
## ``1`` and mutable field ``b`` of type string with default value ``"a"``, and the
## constructor called ``initTypeA``. Let's create na exemplar of it:
##
## .. code-block:: nim
##   var x = initTypeA(b = "b")
##   assert x.a == 1
##   assert x.b == "b"
##   # You can assign values to the field b:
##   x.b = "a"
##   # But the next assignment produces compile time error, because field a is immutable.
##   # Let's check this:
##   assert compiles((block:
##     x.a = 2
##   ))
##
## Now let's create the generic type ``TypeB``, derived from ``TypeA``:
##
## .. code-block:: nim
##   data TypeB[C,D] of TypeA:
##     c: C
##     var d: D
##   var y = initTypeB(100, "aaa", 'a', 1.0)
##
## Derived types knows aboud default vaules, so you can create object like this:
##
## .. code-block:: nim
##   var y = initTypeB(c = 'a', d = 1.0)
##
## You can also create reference object types with this syntax
##
## .. code-block:: nim
##   data TypeC ref object of TypeA:
##     c: char
##
## Reference objects constructors names created by adding prefix ``new`` to type name:
##
## .. code-block:: nim
##   var z = newTypeC(c = 'a')
##
##
##  *More documentation is coming, for now please see the tests in tests/boost/test_typeutils.nim*

import macros, options, future, strutils

type
  GenericParam = string
    ## Generic argument description

  GenericParams = seq[GenericParam]
    ## List of generic arguments

  Constructor = object
    ## Constructor description
    name: Option[string]

  ExportOption = enum
    ## What to export?
    ExportNone,
    ExportType,
    ExportFields,
    ExportAll

  GeneratorOptions = object
    toString: bool
    copy: bool

  TypeHeader = object
    ## The description of the generated type
    name*: string ## The name of the type
    genericParams*: Option[GenericParams] ## Type's generic arguments
    isRef*: bool ## Is it ref type
    isFinal*: bool ## Is the object is final
    parentName*: Option[string] ## Parent type's name
    parentGenericParams*: Option[GenericParams] ## Parent type's generic arguments
    constructor*: Option[Constructor] ## Constructor description
    exportOption*: ExportOption ## Export option
    generatorOptions*: GeneratorOptions
    parentImpl*: Option[Type] ## Parent implementation

  Field = object
    ## Field description
    name*: string ## Field's name
    `type`*: string ## Field's type
    mutable*: bool ## Is the field mutable?
    defValue*: Option[string] ## Optional default value
    caseBranches*: Option[CaseBranches] ## Branches of case field

  Fields = seq[Field]

  CaseBranch = object
    ## Description of the case field's branch
    caseCond*: Option[string] ## Optional (for ``else`` branch) condition
    fields*: seq[Field]

  CaseBranches = seq[CaseBranch]

  Type = ref object
    ## Type description
    header*: TypeHeader  ## Type's header
    fields*: Fields ## Type's fields

  TypeHierarchy = seq[Type]

proc newGeneratorOptions(
  toString = false,
  copy = false
): GeneratorOptions =
  result.toString = toString
  result.copy = copy

proc newTypeHeader(
  name: string,
  genericParams: Option[GenericParams],
  isRef: bool,
  isFinal: bool,
  parentName: Option[string],
  parentGenericParams: Option[GenericParams],
  constructor: Option[Constructor],
  exportOption: ExportOption,
  generatorOptions: GeneratorOptions
): TypeHeader =
  result.name = name
  result.genericParams = genericParams
  result.isRef = isRef
  result.parentName = parentName
  result.parentGenericParams = parentGenericParams
  result.constructor = constructor
  result.exportOption = exportOption
  result.generatorOptions = generatorOptions
  result.parentImpl = Type.none

proc newField(
  name,
  `type`: string,
  mutable: bool,
  defValue: Option[string],
  caseBranches: Option[CaseBranches]
): Field =
  result.name = name
  result.`type` = `type`
  result.mutable = mutable
  result.defValue = defValue
  result.caseBranches = caseBranches

proc realName(f: Field): string =
  if f.mutable:
    f.name
  else:
    f.name & "_impl"

proc newType(
  header: TypeHeader,
  fields: Fields
): Type =
  new result
  result.header = header
  result.fields = fields

# Workaround for VM bug
proc isNil(t: Type): bool =
  t == nil or t.header.name.isNil

proc `$`(t: Type): string =
  if t.isNil:
    "[NilType]"
  else:
    "Type(" & t.header.name & ")"

proc getTypeHierarchy(t: Type): TypeHierarchy =
  ## Returns the list of types, base type first
  result = @[]
  var ct = t.some
  while ct.isSome:
    result = ct.get & result
    ct = result[0].header.parentImpl

proc fields(th: TypeHierarchy): Fields =
  result = newSeq[Field]()
  for t in th:
    result.add(t.fields)

proc exportConstructor(o: ExportOption): bool =
  o == ExportAll

proc exportType(o: ExportOption): bool =
  o >= ExportType

proc exportFields(o: ExportOption): bool =
  o >= ExportFields

proc exportAdditionalProcs(o: ExportOption): bool =
  o >= ExportFields

when false:
  proc parseTypeDef(t: NimNode): (TypeHeader, Fields) {.compileTime.} =
    expectKind t, nnkTypeDef
    expectLen t, 3
    var obj: NimNode
    var isRef: bool
    var genParams: NimNode
    var underlyingGenParams = newEmptyNode()
    var underlyingAlias = newEmptyNode()

    case t[2].typeKind
    of ntyObject:
      isRef = false
    of ntyRef:
      isRef = true
    else:
      error("Unexpected type kind " & $t.typeKind)

    if isRef:
      obj = t[2][0]
    else:
      obj = t[2]

    genParams = t[1]

    var maxIter = 10
    while maxIter != 0:
      dec maxIter
      case obj.kind
      of nnkTypeDef:
        underlyingGenParams = obj[1]
        obj = obj[2]
      of nnkObjectTy:
        break
      of nnkSym:
        obj = obj.getType
      of nnkBracketExpr:
        underlyingAlias = obj
        obj = obj[0].symbol.getImpl
      else:
        error("Unexpected underlying type kind " & $t.typeKind)
      if maxIter == 0:
        error("Infinite cycle detected while searching for object fields")

    expectLen obj, 3
    let recList = obj[2]
    expectKind recList, nnkRecList

    result[0] = newTypeHeader(
      name = t[0].`$`,
      genericParameters
    )

proc genConstructorImpl(`type`: NimNode, n: Option[string], exported: bool): NimNode =
  # See discussion here: https://forum.nim-lang.org/t/2810
  expectLen `type`.getTypeInst, 2
  var t = `type`.getTypeInst[1]
  expectKind t, nnkSym
  t = t.symbol.getImpl
  expectLen t, 3
  var obj: NimNode
  var isRef: bool
  var genParams: NimNode
  var underlyingGenParams = newEmptyNode()
  var underlyingAlias = newEmptyNode()

  case t[2].typeKind
  of ntyObject:
    isRef = false
  of ntyRef:
    isRef = true
  else:
    error("Unexpected type kind " & $t.typeKind)

  if isRef:
    obj = t[2][0]
  else:
    obj = t[2]

  genParams = t[1]

  var maxIter = 10
  while maxIter != 0:
    dec maxIter
    case obj.kind
    of nnkTypeDef:
      underlyingGenParams = obj[1]
      obj = obj[2]
    of nnkObjectTy:
      break
    of nnkSym:
      obj = obj.getType
    of nnkBracketExpr:
      underlyingAlias = obj
      obj = obj[0].symbol.getImpl
    else:
      error("Unexpected underlying type kind " & $t.typeKind)
  if maxIter == 0:
    error("Infinite cycle detected while searching for object fields")

  expectLen obj, 3
  let recList = obj[2]
  expectKind recList, nnkRecList

  let name = if n.isSome: n.get else: if isRef: "new" & $`type` else: "init" & $`type`
  let nameI = if exported: postfix(ident(name), "*") else: ident(name)

  var params = newSeq[NimNode]()
  if genParams.kind == nnkEmpty:
    params.add(`type`)
  else:
    let brExpr = newNimNode(nnkBracketExpr)
    brExpr.add(ident($`type`))
    for p in genParams:
      brExpr.add(ident($p))
    params.add(brExpr)
  for field in recList:
    let idef = case field.kind
    of nnkIdentDefs:
      if field[0].kind == nnkPostfix:
        newIdentDefs(field[0][1].copyNimNode, field[1].copyNimTree)
      else:
        field.copyNimTree
    else:
      newIdentDefs(ident($field), parseExpr(repr(field.getTypeInst)))
    if underlyingAlias.kind != nnkEmpty and underlyingGenParams.kind != nnkEmpty:
      for i in 0..<underlyingGenParams.len:
        if idef[1].kind == nnkIdent and $(underlyingGenParams[i].symbol) == $(idef[1]):
          idef[1] = parseExpr($(underlyingAlias[i+1]))

    params.add(idef)

  let body = newStmtList()
  if isRef:
    body.add newCall(ident"new", ident"result")
  for field in recList:
    let name =
      case field.kind
      of nnkIdentDefs:
        if field[0].kind == nnkPostfix:
          $field[0][1]
        else:
          $field[0]
      else:
        $field
    var i = ident(name)
    body.add newAssignment(newDotExpr(ident"result", i), i)

  result = newProc(nameI, params, body)
  if genParams.kind != nnkEmpty:
    result[2] = newNimNode(nnkGenericParams)
    for p in genParams:
      result[2].add(newIdentDefs(ident($p), newEmptyNode()))

macro genConstructor*(`type`: typed, args: varargs[untyped]): untyped =
  ## Generates constructor for the `type`. The second optional parameter
  ## is the name of the constructor. By default it's ``newType`` for
  ## the ref objects and ``initType`` for the objects. The third optional
  ## parameter is the word ``exported`` and means that the constructor
  ## must be exported.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
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
             of 0: string.none
             else:
               if args.len == 1 and exported: string.none else: ($args[0]).some
  result = genConstructorImpl(`type`, name, exported)

# The implementation of data macro

proc parseIdentOrDotExpr(n: NimNode): string {.compileTime.} =
  expectKind n, {nnkIdent, nnkDotExpr}
  case n.kind
  of nnkIdent:
    result = $n
  else:
    result = parseIdentOrDotExpr(n[0]) & "." & parseIdentOrDotExpr(n[1])

proc mkIdentOrDotExpr(s: string): NimNode {.compileTime.} =
  let i = rfind(s, '.')
  if i == -1:
    result = ident(s)
  else:
    result = newDotExpr(mkIdentOrDotExpr(s[0..i-1]), ident(s[i+1..^1]))

proc parseType(n: NimNode): (string, Option[GenericParams]) {.compileTime.} =
  expectKind n, {nnkIdent, nnkBracketExpr}
  if n.kind == nnkIdent:
    result[0] = $n
    result[1] = GenericParams.none
  else:
    result[0] = $n[0]
    var gp = newSeq[GenericParam](n.len - 1)
    for i in 1..<n.len:
      gp[i-1] = repr(n[i])
    result[1] = gp.some

proc mkType(t: Type): NimNode {.compileTime.} =
  if t.header.genericParams.isNone:
    return ident(t.header.name)
  result = newNimNode(nnkBracketExpr)
  result.add(ident(t.header.name))
  for p in t.header.genericParams.get:
    result.add(ident(p))

proc parseParentType(n: NimNode): (string, Option[GenericParams]) {.compileTime.} =
  expectKind n, {nnkIdent, nnkBracketExpr, nnkDotExpr}
  if n.kind in {nnkIdent, nnkDotExpr}:
    result[0] = parseIdentOrDotExpr(n)
    result[1] = GenericParams.none
  else:
    result[0] = parseIdentOrDotExpr(n[0])
    var gp = newSeq[GenericParam](n.len - 1)
    for i in 1..<n.len:
      gp[i-1] = repr(n[i])
    result[1] = gp.some

proc mkParentType(t: Type): NimNode {.compileTime.} =
  if t.header.parentName.isNone:
    #???
    return newEmptyNode()
  if t.header.parentGenericParams.isNone:
    return mkIdentOrDotExpr(t.header.parentName.get)
  result = newNimNode(nnkBracketExpr)
  result.add(mkIdentOrDotExpr(t.header.parentName.get))
  for p in t.header.parentGenericParams.get:
    result.add(ident(p))

proc parseTypeHeader(head: NimNode, modifiers: seq[NimNode]): TypeHeader =
  case head.kind
  of nnkIdent:
    result = newTypeHeader(
      $head,
      GenericParams.none,
      false,
      false,
      string.none,
      GenericParams.none,
      Constructor.none,
      ExportNone,
      newGeneratorOptions()
    )
  of nnkInfix:
    expectKind head[0], nnkIdent
    if head[0].`$` == "of":
      expectLen head, 3
      let (name, gp) = parseType(head[1])
      let (pname, pgp) = parseParentType(head[2])
      result = newTypeHeader(
        name,
        gp,
        false,
        false,
        pname.some,
        pgp,
        Constructor.none,
        ExportNone,
        newGeneratorOptions()
      )
    elif head[0].`$` == "ref":
      expectLen head, 3
      expectKind head[1], nnkIdent
      expectKind head[2], {nnkObjectTy, nnkInfix}
      var parent = string.none
      if head[2].kind == nnkInfix:
        expectKind head[2][0], nnkIdent
        if head[2][0].`$` != "of":
          error "Wrong data header syntax: " & treeRepr(head)
        expectKind head[2][1], nnkObjectTy
        parent = parseIdentOrDotExpr(head[2][2]).some
      result = newTypeHeader(
        $head[1],
        GenericParams.none,
        true,
        false,
        parent,
        GenericParams.none,
        Constructor.none,
        ExportNone,
        newGeneratorOptions()
      )
    else:
      error "Wrong data header syntax: " & treeRepr(head)
  of nnkBracketExpr:
    # Generic type
    expectMinLen head, 2
    var genArgs = newSeq[GenericParam](head.len - 1)
    for i in 1..<head.len:
      genArgs[i - 1] = repr(head[i])
    result = newTypeHeader(
      $head[0],
      genArgs.some,
      false,
      false,
      string.none,
      GenericParams.none,
      Constructor.none,
      ExportNone,
      newGeneratorOptions()
    )
  else:
    error "Unexpected header: " & treeRepr(head)
  for m in modifiers:
    if m.kind == nnkIdent and $m == "exported":
      result.exportOption = ExportAll
    elif m.kind == nnkIdent and $m == "show":
      result.generatorOptions.toString = true
    elif m.kind == nnkIdent and $m == "copy":
      result.generatorOptions.copy = true
    else:
      error "Unknown data type modifier: " & repr(m)

proc parseFields(body: NimNode): Fields =
  expectKind body, nnkStmtList
  result = newSeq[Field]()
  for sdef in body:
    case sdef.kind
    of nnkCall:
      expectLen sdef, 2
      expectKind sdef[0], {nnkIdent, nnkAccQuoted}
      expectKind sdef[1], nnkStmtList
      result.add newField(
        name = $sdef[0],
        `type` = sdef[1][0].repr(),
        mutable = false,
        defValue = string.none,
        caseBranches = CaseBranches.none
      )
    of nnkAsgn:
      expectLen sdef, 2
      expectKind sdef[0], {nnkIdent, nnkAccQuoted}
      result.add newField(
        name = $sdef[0],
        `type` = "type(" & repr(sdef[1]) & ")",
        mutable = false,
        defValue = repr(sdef[1]).some,
        caseBranches = CaseBranches.none
      )
    of nnkLetSection, nnkVarSection:
      expectKind sdef[0], nnkIdentDefs
      let idef = sdef[0]
      let name = $idef[0]
      let `type` = if idef[1].kind == nnkEmpty:
                   "type(" & repr(idef[2]) & ")"
                 else:
                   repr(idef[1])
      let mutable = sdef.kind == nnkVarSection
      let defValue = if idef[2].kind == nnkEmpty: string.none
                     else: repr(idef[2]).some
      result.add newField(
        name, `type`, mutable, defValue, CaseBranches.none
      )
    of nnkCommentStmt:
      discard
    else:
      error "Unexpected field description: " & treeRepr(sdef)

when defined(insideTheTest):
  export GenericParam,
     GenericParams,
     Constructor,
     ExportOption,
     TypeHeader,
     Field,
     Fields,
     CaseBranch,
     CaseBranches,
     Type

proc genDataTypeBody(t: Type): NimNode {.compileTime.} =
  let recList = newNimNode(nnkRecList)
  for field in t.fields:
    let ident = if t.header.exportOption.exportFields: postfix(ident(field.realName), "*") else: ident(field.realName)
    let identDefs = newIdentDefs(ident, parseExpr(field.`type`))
    recList.add(identDefs)
  result = newNimNode(nnkObjectTy).add(newEmptyNode())
  # Inheritance
  if t.header.parentName.isNone:
    if t.header.isFinal:
      result.add(newEmptyNode())
    else:
      result.add(newNimNode(nnkOfInherit).add(ident"RootObj"))
  else:
    result.add(newNimNode(nnkOfInherit).add(t.mkParentType))
  result.add(recList)
  if t.header.isRef
:
    result = newNimNode(nnkRefTy).add(result)

proc genDataTypeNameNode(typeHeader: TypeHeader): NimNode {.compileTime.} =
  let nameI = if typeHeader.exportOption.exportType: postfix(ident(typeHeader.name), "*")
              else: ident(typeHeader.name)
  if typeHeader.parentName.isSome and typeHeader.isFinal:
    # Marking the object as final via pragma, if it has no parent, then it'll be done in the
    # genDataTypeBody function
    result = newNimNode(nnkPragmaExpr).add(nameI).add(newNimNode(nnkPragma).add(ident"final"))
  else:
    result = nameI

proc genGenericParams(ps: GenericParams): NimNode {.compileTime.} =
  # Generates nnkGenericParams
  #TODO: Implement this correctly
  result = newNimNode(nnkGenericParams)
  for p in ps:
    result.add(newIdentDefs(ident($p), newEmptyNode()))

proc genDataType(t: Type): NimNode {.compileTime.} =
  let `type` = newNimNode(nnkTypeDef)
  # Type name
  `type`.add(genDataTypeNameNode(t.header))
  # Generic parameters
  if t.header.genericParams.isSome:
    `type`.add(genGenericParams(t.header.genericParams.get))
  else:
    `type`.add(newEmptyNode())
  # Type implementation
  `type`.add(genDataTypeBody(t))
  result = newNimNode(nnkTypeSection).add(`type`)

proc fillProcGenericParams(p: NimNode, t: Type) =
  if t.header.genericParams.isSome:
    p[2] = genGenericParams(t.header.genericParams.get)

proc getConstructorName(t: Type): string =
  if t.header.constructor.isSome and t.header.constructor.get.name.isSome:
    t.header.constructor.get.name.get
  else:
    if t.header.isRef:
      "new" & t.header.name
    else:
      "init" & t.header.name

proc genDataConstructor(t: Type): NimNode {.compileTime.} =
  # Constructor must use all the fields from the object and all of it's
  # ancestors
  let fields = t.getTypeHierarchy.fields
  let nameI = ident(t.header.name)
  let procName = t.getConstructorName
  let procNameI = if t.header.exportOption.exportConstructor: postfix(ident(procName), "*") else: ident(procName)

  var params = newSeq[NimNode]()
  params.add(t.mkType)
  for field in fields:
    params.add(newIdentDefs(
      ident(field.name),
      parseExpr(field.`type`),
      if field.defValue.isSome:
        parseExpr(field.defValue.get)
      else:
        newEmptyNode()
    ))

  let body = newStmtList()
  if t.header.isRef:
    body.add newCall(ident"new", ident"result")
  for field in fields:
    body.add newAssignment(
      newDotExpr(
        ident"result",
        ident(field.realName)
      ),
      ident(field.name)
    )

  result = newProc(procNameI, params, body)
  fillProcGenericParams(result, t)

proc genDataGetter(t: Type, fields: Fields, fieldIdx: int): NimNode {.compileTime.} =
  let f = fields[fieldIdx]
  let procIdent = if t.header.exportOption.exportFields(): postfix(ident(f.name), "*") else: ident(f.name)
  let fieldIdent = ident(f.realName)
  let typeIdent = t.mkType
  let fieldType = parseExpr(f.`type`)

  result = quote do:
    proc `procIdent`(v: `typeIdent`): `fieldType` {.used.} =
      v.`fieldIdent`

  fillProcGenericParams(result[0], t)

proc genDataGetters(t: Type): NimNode {.compileTime.} =
  let fields = t.getTypeHierarchy.fields
  result = newStmtList()
  for i in 0..<fields.len:
    if not fields[i].mutable:
      result.add genDataGetter(t, fields, i)
  if result.len == 0:
    result = newEmptyNode()

proc genShowProc(t: Type): NimNode {.compileTime.} =
  let typeIdent = t.mkType
  let nameStr = newStrLitNode(t.header.name)
  var procIdent = newNimNode(nnkAccQuoted).add(ident"$")
  if t.header.exportOption.exportAdditionalProcs:
    procIdent = postfix(procIdent, "*")
  var vIdent = ident"v"
  var resIdent = ident"res"
  var body = newStmtList()

  for i in 0..<t.fields.len:
    let f = t.fields[i]
    let fIdent = ident(f.name)
    let fName = newStrLitNode(f.name)
    let splitter = if i == 0: newStrLitNode("") else: newStrLitNode(", ")
    body.add quote do:
      `resIdent` &= `splitter` & `fName` & ": "
      when compiles($(`vIdent`.`fIdent`)):
        `resIdent` &= $(`vIdent`.`fIdent`)
      else:
        `resIdent` &= "..."

  result = quote do:
    proc `procIdent`(`vIdent`: `typeIdent`): string =
      var `resIdent` = `nameStr` & "("
      `body`
      `resIdent` &= ")"
      return `resIdent`

  fillProcGenericParams(result[0], t)

proc genCopyMacro(t: Type): NimNode {.compileTime.} =
  let consName = newStrLitNode(t.getConstructorName)
  let macroName = if t.header.exportOption.exportAdditionalProcs:
                    postfix(ident("copy" & t.header.name), "*")
                  else:
                   ident("copy" & t.header.name)
  let fields = newNimNode(nnkBracket)
  for f in t.fields:
    fields.add(newNimNode(nnkPar).add(newStrLitNode(f.name), parseExpr("nil.NimNode")))
  result = quote do:
    macro `macroName`(args: varargs[untyped]): untyped =
      expectKind args, nnkArgList
      expectMinLen args, 1
      var fields = `fields`
      for i in 1..<args.len:
        expectKind args[i], nnkExprEqExpr
        expectKind args[i][0], nnkIdent
        for j in 0..<fields.len:
          if fields[j][0] == $(args[i][0]):
            fields[j][1] = args[i][1]
      let s = genSym(nskVar)
      let call = newCall(ident(`consName`))
      for f in fields:
        if f[1].isNil:
          call.add(newDotExpr(s, ident(f[0])))
        else:
          call.add(f[1])
      return newNimNode(nnkStmtListExpr)
      .add(newVarStmt(s, args[0]))
      .add(call)

proc genAdditionalProcs(t: Type): NimNode {.compileTime.} =
  result = newStmtList()
  if t.header.generatorOptions.toString:
    result.add(genShowProc(t))
  if t.header.generatorOptions.copy:
    result.add(genCopyMacro(t))

var lastType {.compileTime.} = Type()
var typesTable {.compileTime.} = newSeq[(NimNode, Type)]()

proc findSymImpl(sym: NimNode): Option[Type] =
  result = Type.none
  for t in typesTable:
    if sym == t[0]:
      result = t[1].some
      break

macro appendType(t: typed): untyped =
  if lastType.isNil:
    error "Last type not found"

  typesTable.add((t, lastType))

  # Can't use nil because of VM bug
  lastType = Type()

  result = newEmptyNode()

proc dataImpl(parentSymO: Option[NimNode]): NimNode {.compileTime.} =
  if lastType.isNil:
    error "Last type not found"

  lastType.header.parentImpl = if parentSymO.isSome: findSymImpl(parentSymO.get)
                               else: Type.none
  if parentSymO.isSome and lastType.header.parentImpl.isNone:
    error "Can't find the implementation of the parent type " & parentSymO.get.`$`

  result = newStmtList()
  result.add(genDataType(lastType))
  result.add(genDataConstructor(lastType))
  result.add(genDataGetters(lastType))
  result.add(genAdditionalProcs(lastType))
  result.add(newCall(bindSym"appendType", ident(lastType.header.name)))

macro dataImplWithParent(parent: typed): untyped =
  result = dataImpl(parent.some)

macro dataImplWithoutParent(): untyped =
  result = dataImpl(NimNode.none)

proc dataPreImpl(head, body: NimNode, modifiers: seq[NimNode]): NimNode =
  # Parses type header, fields, then
  # calls the real generator macro, that has typed parent
  let header = parseTypeHeader(head, modifiers)
  let fields = parseFields(body)
  lastType = newType(header, fields)
  if header.parentName.isSome:
    result = newCall(bindSym"dataImplWithParent", mkIdentOrDotExpr(header.parentName.get))
  else:
    result = newCall(bindSym"dataImplWithoutParent")

macro data*(args: varargs[untyped]): untyped =
  if args.len < 2:
    error "Wrong data macro usage, you must specify type header, optional modifiers and then type's body"
  var m = newSeq[NimNode](args.len - 2)
  for i in 0..<(args.len-2):
    m[i] = args[i+1]
  result = dataPreImpl(args[0], args[^1], m)

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

  ExportedThing = enum
    ## What to export?
    ExportType,
    ExportFields,
    ExportConstructor,
    ExportShow,
    ExportCopy,
    ExportEq,
    ExportJson,

  ExportOption = set[ExportedThing]

const ExportAll: ExportOption = {
  ExportType, ExportFields, ExportConstructor, ExportShow, ExportCopy, ExportEq, ExportJson
}

const ExportNone: ExportOption = {}

type
  GeneratorOptions = object
    toString: bool
    copy: bool
    eq: bool
    json: bool

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
    case branch*: bool
    of true:
      fields*: seq[Field]
    else:
      `type`*: string ## Field's type
      mutable*: bool ## Is the field mutable?
      defValue*: Option[string] ## Optional default value

  Fields = seq[Field]

  Type = ref object
    ## Type description
    header*: TypeHeader  ## Type's header
    fields*: Fields ## Type's fields

  TypeHierarchy = seq[Type]

proc newGeneratorOptions(
  toString = false,
  copy = false,
  eq = false,
  json = false
): GeneratorOptions =
  result.toString = toString
  result.copy = copy
  result.eq = eq
  result.json = json

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

proc newConstructor(name: Option[string]): Constructor =
  result.name = name

proc newField(
  name,
  `type`: string,
  mutable: bool,
  defValue: Option[string]
): Field = Field(
  name: name,
  branch: false,
  `type`: `type`,
  mutable: mutable,
  defValue: defValue
)

proc newBranch(
  name: string,
  fields: seq[Field]
): Field = Field(
  name: name,
  branch: true,
  fields: fields
)

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

proc getAllBranchesFields(t: Type): Fields =
  result = newSeq[Field]()
  for f in t.fields:
    if f.branch:
      result.add(f.fields)
    else:
      result.add(f)

proc getOnlyFields(t: Type): Fields =
  result = newSeq[Field]()
  for f in t.fields:
    if not f.branch:
      result.add(f)

proc getThisBranchFields(b: Field, t: Type): Fields =
  result = t.getOnlyFields & b.fields

proc getBranches(t: Type): Fields =
  result = newSeq[Field]()
  for f in t.fields:
    if f.branch:
      result.add(f)

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

proc isAdt(t: Type): bool =
  for f in t.fields:
    if f.branch:
      return true

proc hasParent(t: Type): bool =
  result = t.header.parentName.isSome

proc getAdtEnumName(t: Type): string =
  result = t.header.name & "Kind"

proc mkBranchField(t: Type): Field =
  newField(
    name = "kind",
    `type` = t.getAdtEnumName,
    mutable = true,
    defValue = string.none
  )

proc exportConstructor(o: ExportOption): bool =
  ExportConstructor in o

proc exportType(o: ExportOption): bool =
  ExportType in o

proc exportFields(o: ExportOption): bool =
  ExportFields in o

proc exportShow(o: ExportOption): bool =
  ExportShow in o

proc exportCopy(o: ExportOption): bool =
  ExportCopy in o

proc exportEq(o: ExportOption): bool =
  ExportEq in o

proc exportJson(o: ExportOption): bool =
  ExportJson in o

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

proc parseModifiers(header: var TypeHeader, modifiers: seq[NimNode]) =
  template `-=`[T](r: var set[T], v: T) =
    r = r - {v}
  for m in modifiers:
    if m.kind == nnkIdent and $m == "exported" or
       m.kind == nnkCall and m[0].kind == nnkIdent and $m[0] == "exported":
      header.exportOption = ExportAll
      if(m.kind == nnkCall):
        for i in 1..<m.len:
          let mm = m[i]
          case $mm
          of "noconstructor":
            header.exportOption -= ExportConstructor
          of "noshow":
            header.exportOption -= ExportShow
          of "nocopy":
            header.exportOption -= ExportCopy
          of "nofields":
            header.exportOption -= ExportFields
          of "noeq":
            header.exportOption -= ExportEq
          of "nojson":
            header.exportOption -= ExportJson
          else:
            error "Unknown export modifier: " & repr(mm)
    elif m.kind == nnkIdent and $m == "show":
      header.generatorOptions.toString = true
    elif m.kind == nnkIdent and $m == "copy":
      header.generatorOptions.copy = true
    elif m.kind == nnkIdent and $m == "eq":
      header.generatorOptions.eq = true
    elif m.kind == nnkIdent and $m == "json":
      header.generatorOptions.json = true
    elif m.kind == nnkCall and m[0].kind == nnkIdent and m[0].`$` == "constructor":
      if(m.len != 2 or m[1].kind != nnkIdent):
        error "Wrong constructor modifier syntax: " & repr(m)
      else:
        header.constructor = newConstructor(m[1].`$`.some).some
    else:
      error "Unknown data type modifier: " & repr(m)

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
      let (name, gp) = parseType(head[1])
      expectKind head[2], {nnkObjectTy, nnkInfix}
      var pname = string.none
      var pgp = GenericParams.none
      if head[2].kind == nnkInfix:
        expectKind head[2][0], nnkIdent
        if head[2][0].`$` != "of":
          error "Wrong data header syntax: " & treeRepr(head)
        expectKind head[2][1], nnkObjectTy
        let (parent, parentgp) = parseParentType(head[2][2])
        pname = parent.some
        pgp = parentgp
      result = newTypeHeader(
        name,
        gp,
        true,
        false,
        pname,
        pgp,
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
  parseModifiers(result, modifiers)

proc isBranch(n: NimNode): bool {.compileTime.} =
  expectKind n, nnkStmtList
  result = true
  for ch in n:
    if ch.kind notin {nnkCall, nnkAsgn, nnkLetSection, nnkVarSection, nnkDiscardStmt}:
      return false

proc parseFields(body: NimNode): Fields {.compileTime.} =
  expectKind body, nnkStmtList
  result = newSeq[Field]()
  for sdef in body:
    case sdef.kind
    of nnkCall:
      expectLen sdef, 2
      expectKind sdef[0], {nnkIdent, nnkAccQuoted}
      expectKind sdef[1], nnkStmtList
      # We need to check, if it's a branch (all the children of sdef[1] must be of type {nnkCall, nnkAsgn, nnkLetSection, nnkVarSection})
      if sdef[1].isBranch:
        result.add newBranch(
          name = $sdef[0],
          fields = parseFields(sdef[1])
        )
      else:
        result.add newField(
          name = $sdef[0],
          `type` = sdef[1][0].repr(),
          mutable = false,
          defValue = string.none
        )
    of nnkAsgn:
      expectLen sdef, 2
      expectKind sdef[0], {nnkIdent, nnkAccQuoted}
      result.add newField(
        name = $sdef[0],
        `type` = "type(" & repr(sdef[1]) & ")",
        mutable = false,
        defValue = repr(sdef[1]).some
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
        name, `type`, mutable, defValue
      )
    of nnkCommentStmt, nnkDiscardStmt:
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
     Type

proc genBranchRecList(t: Type, branch: Fields): NimNode {.compileTime.} =
  result = newNimNode(nnkRecList)
  for field in branch:
    let ident = if t.header.exportOption.exportFields: postfix(ident(field.realName), "*") else: ident(field.realName)
    let identDefs = newIdentDefs(ident, parseExpr(field.`type`))
    result.add(identDefs)

proc genDataTypeBody(t: Type): NimNode {.compileTime.} =
  var recList: NimNode
  if t.isAdt:
    recList = genBranchRecList(t, t.getOnlyFields)
    let recCase = newNimNode(nnkRecCase)
    recCase.add(newIdentDefs(ident"kind", ident(t.getAdtEnumName)))
    for f in t.getBranches:
      let ofBranch = newNimNode(nnkOfBranch)
      ofBranch.add(ident(f.name))
      ofBranch.add(genBranchRecList(t, f.fields))
      recCase.add(ofBranch)
    recList.add(recCase)
  else:
    recList = genBranchRecList(t, t.fields)
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
  if t.header.isRef:
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

proc genAdtEnum(t: Type): NimNode {.compileTime.} =
  result = newNimNode(nnkTypeDef)
  if t.header.exportOption.exportFields():
    result.add(postfix(ident(t.getAdtEnumName), "*"))
  else:
    result.add(ident(t.getAdtEnumName))
  result.add(newEmptyNode())
  let enumTy = newNimNode(nnkEnumTy)
  enumTy.add(newEmptyNode())
  for b in t.getBranches:
    enumTy.add(ident(b.name))
  result.add(enumTy)

proc genDataType(t: Type): NimNode {.compileTime.} =
  result = newNimNode(nnkTypeSection)
  if t.isAdt:
    result.add(genAdtEnum(t))
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
  result.add(`type`)

proc fillProcGenericParams(p: NimNode, t: Type) =
  if t.header.genericParams.isSome:
    p[2] = genGenericParams(t.header.genericParams.get)

proc getConstructorName(t: Type, branch: Option[Field] = Field.none): string =
  if branch.isNone and t.header.constructor.isSome and t.header.constructor.get.name.isSome:
    t.header.constructor.get.name.get
  else:
    let name = if branch.isSome: branch.get.name else: t.header.name
    if t.header.isRef:
      "new" & name
    else:
      "init" & name

proc getBranchFieldsWithKind(t: Type, branch: Field): Fields =
  let onlyFields = t.getOnlyFields
  result = newSeqOfCap[Field](onlyFields.len + branch.fields.len + 1)
  result.add(t.mkBranchField)
  result.add(onlyFields)
  result.add(branch.fields)

proc genDataConstructor(t: Type, branch: Option[Field] = Field.none): NimNode {.compileTime.} =
  let fields = if branch.isSome: t.getBranchFieldsWithKind(branch.get) else: t.getTypeHierarchy.fields
  let procName = t.getConstructorName(branch)
  let procNameI = if t.header.exportOption.exportConstructor: postfix(ident(procName), "*") else: ident(procName)

  var params = newSeq[NimNode]()
  params.add(t.mkType)
  let start = if branch.isSome: 1 else: 0
  for idx in start..<fields.len:
    let field = fields[idx]
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
  for idx in 0..<fields.len:
    let field = fields[idx]
    let value = if branch.isSome and idx == 0: ident(branch.get.name) else: ident(field.name)
    body.add newAssignment(
      newDotExpr(
        ident"result",
        ident(field.realName)
      ),
      value
    )

  result = newProc(procNameI, params, body)
  fillProcGenericParams(result, t)
  let used = newNimNode(nnkPragma).add(ident"used")
  result[4] = used

proc genDataConstructors(t: Type): NimNode {.compileTime.} =
  if t.isAdt:
    result = newStmtList()
    # ADT has as many constructors as branches
    for b in t.getBranches:
      result.add genDataConstructor(t, b.some)
  else:
    result = genDataConstructor(t)

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
  let fields = if t.isAdt: t.getAllBranchesFields else: t.getTypeHierarchy.fields
  result = newStmtList()
  for i in 0..<fields.len:
    if not fields[i].mutable:
      result.add genDataGetter(t, fields, i)
  if result.len == 0:
    result = newEmptyNode()

proc genParamConcatenation(resIdent: NimNode, vIdent: NimNode, fields: Fields): NimNode =
  result = newStmtList()
  for i in 0..<fields.len:
    let f = fields[i]
    let fIdent = ident(f.name)
    let fName = newStrLitNode(f.name)
    let splitter = if i == 0: newStrLitNode("") else: newStrLitNode(", ")
    result.add quote do:
      `resIdent` &= `splitter` & `fName` & ": "
      when compiles($(`vIdent`.`fIdent`)):
        `resIdent` &= $(`vIdent`.`fIdent`)
      else:
        `resIdent` &= "..."

proc genShowProc(t: Type): NimNode {.compileTime.} =
  let typeIdent = t.mkType
  var vIdent = ident"v"
  var resIdent = ident"res"
  var nameStr: NimNode
  if t.isAdt:
    nameStr = quote do: $(`vIdent`.kind)
  else:
    nameStr = newStrLitNode(t.header.name)
  var procIdent = newNimNode(nnkAccQuoted).add(ident"$")
  if t.header.exportOption.exportShow:
    procIdent = postfix(procIdent, "*")
  var body: NimNode
  if t.isAdt:
    body = newStmtList()
    for b in t.getBranches:
      let branchBody = genParamConcatenation(resIdent, vIdent, b.getThisBranchFields(t))
      let branchIdent = ident(b.name)
      body.add quote do:
        if `vIdent`.kind == `branchIdent`:
          `branchBody`
  else:
    body = genParamConcatenation(resIdent, vIdent, t.fields)

  result = quote do:
    proc `procIdent`(`vIdent`: `typeIdent`): string {.used.} =
      var `resIdent` = `nameStr` & "("
      `body`
      `resIdent` &= ")"
      return `resIdent`

  fillProcGenericParams(result[0], t)

proc genCopyMacro(t: Type, branch: Option[Field] = Field.none): NimNode {.compileTime.} =
  let consName = newStrLitNode(t.getConstructorName(branch))
  let typeName = if branch.isSome: branch.get.name else: t.header.name
  let macroIdent = if t.header.exportOption.exportCopy:
                    postfix(ident("copy" & typeName), "*")
                  else:
                   ident("copy" & typeName)
  let fields = if branch.isSome: branch.get.getThisBranchFields(t) else: t.getTypeHierarchy.fields
  let fieldsNode = newNimNode(nnkBracket)
  for f in fields:
    fieldsNode.add(newNimNode(nnkPar).add(newStrLitNode(f.name), parseExpr("nil.NimNode")))
  result = quote do:
    macro `macroIdent`(args: varargs[untyped]): untyped {.used.} =
      expectKind args, nnkArgList
      expectMinLen args, 1
      var fields: seq[(string, NimNode)] = @`fieldsNode`
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

proc genCopyMacros(t: Type): NimNode {.compileTime.} =
  if t.isAdt:
    result = newStmtList()
    for b in t.fields:
      result.add genCopyMacro(t, b.some)
  else:
    result = genCopyMacro(t)

proc genFieldsComparison(x, y: NimNode, fields: Fields): NimNode {.compileTime.} =
  result = newStmtList()
  for f in fields:
    let name = ident(f.name)
    result.add quote do:
      if `x`.`name` != `y`.`name`:
        return false

proc genEqProc(t: Type): NimNode {.compileTime.} =
  let x = ident"x"
  let y = ident"y"

  var body: NimNode
  if t.isAdt:
    body = newStmtList()
    body.add quote do:
      if `x`.kind != `y`.kind:
        return false
    for b in t.getBranches:
      let kind = ident(b.name)
      let comp = genFieldsComparison(x, y, b.getThisBranchFields(t))
      body.add quote do:
        if `x`.kind == `kind`:
          `comp`
  else:
    body = genFieldsComparison(x, y, t.getTypeHierarchy.fields)

  let typeIdent = t.mkType
  let nameI = if t.header.exportOption.exportEq: postfix(parseExpr("`==`"), "*")  else: parseExpr("`==`")
  let res = ident"result"
  result = quote do:
    proc `nameI`(`x`, `y`: `typeIdent`): bool {.used.} =
      `res` = true
      `body`
  fillProcGenericParams(result[0], t)

proc genFromJsonField(j, res: NimNode, f: Field): NimNode =
  let nameS = newStrLitNode(f.name)
  let nameI = ident(f.realName)
  let fType = parseExpr(f.`type`)
  let fTypeS = newStrLitNode(f.`type`)
  result = quote do:
    try:
      if not `j`.contains(`nameS`):
        when `fType` is ref:
          `res`.`nameI` = fromJson(`fType`, nil)
        else:
          raise newFieldException("Can't get value of type " & `fTypeS`)
      else:
        `res`.`nameI` = fromJson(`fType`, `j`[`nameS`])
    except FieldException:
      let e = cast[ref FieldException](getCurrentException())
      e.addPath(`nameS`)
      raise

proc genFromJsonProc(t: Type): NimNode {.compileTime.} =
  let typeIdent = t.mkType
  let procName =
    if t.header.exportOption.exportJson: postfix(ident"fromJson", "*")
    else: ident"fromJson"
  let j = ident"j"

  let body = newStmtList()
  let res = ident"result"
  if t.header.isRef:
    body.add quote do:
      new `res`

  if t.isAdt:
    body.add genFromJsonField(j, res, t.mkBranchField)
    for b in t.getBranches:
      let branchI = ident(b.name)
      let br = newStmtList()
      for f in b.getThisBranchFields(t):
        br.add genFromJsonField(j, res, f)
      body.add quote do:
        if `res`.kind == `branchI`:
          `br`
  else:
    for f in t.getTypeHierarchy.fields:
      body.add genFromJsonField(j, res, f)

  result = quote do:
    proc `procName`(t: typedesc[`typeIdent`], `j`: JsonNode): `typeIdent` {.used.} =
      `body`
  fillProcGenericParams(result[0], t)

proc genToJsonField(v, res: NimNode, f: Field): NimNode =
  let nameS = newStrLitNode(f.name)
  let nameI = ident(f.realName)
  let fType = parseExpr(f.`type`)
  let tmp = genSym(nskVar)
  result = quote do:
    var `tmp` = toJson(`v`.`nameI`)
    when compiles(`tmp`.isNil):
      if not `tmp`.isNil: `res`[`nameS`] = `tmp`
    else:
      `res`[`nameS`] = `tmp`

proc genToJsonProc(t: Type): NimNode {.compileTime.} =
  let typeIdent = t.mkType
  let procName =
    if t.header.exportOption.exportJson: postfix(ident"toJson", "*")
    else: ident"toJson"
  let v = ident"v"

  let body = newStmtList()
  let res = ident"result"

  if t.isAdt:
    body.add genToJsonField(v, res, t.mkBranchField)
    for b in t.getBranches:
      let branchI = ident(b.name)
      let br = newStmtList()
      for f in b.getThisBranchFields(t):
        br.add genToJsonField(v, res, f)
      body.add quote do:
        if `v`.kind == `branchI`:
          `br`
  else:
    for f in t.getTypeHierarchy.fields:
      body.add genToJsonField(v, res, f)

  result = quote do:
    proc `procName`(`v`: `typeIdent`): JsonNode {.used.} =
      `res` = newJObject()
      `body`
  fillProcGenericParams(result[0], t)

proc genJsonProcs(t: Type): NimNode {.compileTime.} =
  result = newStmtList()
  result.add genFromJsonProc(t)
  result.add genToJsonProc(t)

proc genAdditionalProcs(t: Type): NimNode {.compileTime.} =
  result = newStmtList()
  if t.header.generatorOptions.toString:
    result.add(genShowProc(t))
  if t.header.generatorOptions.copy:
    result.add(genCopyMacros(t))
  if t.header.generatorOptions.eq:
    result.add(genEqProc(t))
  if t.header.generatorOptions.json:
    result.add(genJsonProcs(t))

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
  result.add(genDataConstructors(lastType))
  result.add(genDataGetters(lastType))
  result.add(genAdditionalProcs(lastType))
  result.add(newCall(bindSym"appendType", ident(lastType.header.name)))

macro dataImplWithParent(parent: typed): untyped =
  result = dataImpl(parent.some)

macro dataImplWithoutParent(): untyped =
  result = dataImpl(NimNode.none)

proc checkFields(fields: Fields, allowBranches = true) {.compileTime.} =
  var isAdt = false
  var hasFields = false
  for f in fields:
    if f.branch:
      isAdt = true
      if not allowBranches:
        error "Recursive branches are not allowed"
      checkFields(f.fields, false)
    else:
      hasFields = true
      if isAdt:
        error "Common fields must be placed before branches"

proc dataPreImpl(head, body: NimNode, modifiers: seq[NimNode]): NimNode {.compileTime.} =
  # Parses type header, fields, then
  # calls the real generator macro, that has typed parent
  let header = parseTypeHeader(head, modifiers)
  let fields = parseFields(body)
  checkFields(fields)
  lastType = newType(header, fields)
  if lastType.isAdt and lastType.hasParent:
    error "Algebraic data types can't have parent"
  if lastType.hasParent:
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

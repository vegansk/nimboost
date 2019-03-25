import boost/typeutils

type GlobalX* = object
  a*: int
  b*: seq[string]

when compiles(GlobalX.genConstructor):
  GlobalX.genConstructor createGlobalX, exported

data GlobalData, exported:
  a: int

data GlobalDataRef ref object, exported, copy:
  a: int

data TestModifiers, exported(noconstructor,nocopy,noshow,nofields), constructor(testModifiers), copy, show:
  a: int

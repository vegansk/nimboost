import strutils

type
  Prop = object
    name: string
    value: string
  Props* = distinct seq[Prop]

proc prop(n, v: string): Prop = Prop(name: n, value: v)

iterator items*(p: Props): Prop =
  for el in ((seq[Prop])p):
    yield el

iterator pairs*(p: Props): (string, string) =
  for el in p:
    yield (el.name, el.value)

proc len*(p: Props): int =
  ((seq[Prop])p).len

proc getMVar(p: var Props, idx: int): ptr Prop =
  addr(((seq[Prop]p))[idx])

proc `[]`*(p: Props, name: string): string =
  for n, v in p:
    if n.cmpIgnoreCase(name) == 0:
      return v
  return ""

proc `[]=`*(p: var Props; n, v: string) =
  for idx in 0..<p.len:
    var el = getMVar(p, idx)
    if el.name.cmpIgnoreCase(n) == 0:
      el.value = v
      return
  ((seq[Prop])p).add(prop(n, v))

proc add*(p: var Props; n, v: string) =
  for idx in 0..<p.len:
    var el = getMVar(p, idx)
    if el.name.cmpIgnoreCase(n) == 0:
      el.value = el.value & ", " & v
      return
  ((seq[Prop])p).add(prop(n, v))

proc contains*(p: Props, name: string): bool =
  for n, _ in p.pairs:
    if n.cmpIgnoreCase(name) == 0:
      return true

proc newProps*(vals: varargs[tuple[name: string, value: string]]): Props =
  result = (Props)newSeq[Prop]()
  for el in vals:
    result.add(el.name, el.value)

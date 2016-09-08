import strutils, strtabs

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

proc add*(p: var Props; n, v: string, overwrite = false, splitter = ", "): var Props {.discardable.} =
  result = p
  for idx in 0..<p.len:
    var el = getMVar(p, idx)
    if el.name.cmpIgnoreCase(n) == 0:
      if overwrite:
        el.value = v
      else:
        el.value = el.value & splitter & v
      return
  ((seq[Prop])p).add(prop(n, v))

proc `[]=`*(p: var Props; n, v: string) =
  p.add(n, v, overwrite = true)

proc contains*(p: Props, name: string): bool =
  for n, _ in p.pairs:
    if n.cmpIgnoreCase(name) == 0:
      return true

proc newProps*(vals: varargs[tuple[name: string, value: string]], overwrite = false, splitter = ", "): Props =
  result = (Props)newSeq[Prop]()
  for el in vals:
    result.add(el.name, el.value, overwrite, splitter)

proc toSeq*(p: Props): seq[(string, string)] =
  result = newSeq[(string, string)](p.len)
  for idx in 0..<p.len:
    let el = ((seq[Prop])p)[idx]
    result[idx] = (el.name, el.value)

proc clear*(p: var Props) =
  ((seq[Prop])p).setLen(0)

proc isNil*(p: Props): bool =
  ((seq[Prop])p).isNil

proc toStringTable*(p: Props, t: StringTableRef) =
  for k, v in p.pairs:
    t[k] = v

proc asStringTable*(p: Props): StringTableRef =
  result = newStringTable(modeCaseInsensitive)
  p.toStringTable(result)

import strutils, strtabs

## The set of properties. Keys are case insensitive.

type
  Prop = object
    name: string
    value: string
  Props* = distinct seq[Prop]
    ## Set of properties

proc prop(n, v: string): Prop = Prop(name: n, value: v)

iterator items(p: Props): Prop =
  for el in ((seq[Prop])p):
    yield el

iterator pairs*(p: Props): (string, string) =
  ## Iterates key/value pairs
  for el in p:
    yield (el.name, el.value)

proc len*(p: Props): int =
  ## Returns the number of properties
  ((seq[Prop])p).len

proc getMVar(p: var Props, idx: int): ptr Prop =
  addr(((seq[Prop]p))[idx])

proc `[]`*(p: Props, name: string): string =
  ## Returns the property named ``name`` or empty string.
  ## If you need to know, if the property was set, use ``contains``.
  for n, v in p:
    if n.cmpIgnoreCase(name) == 0:
      return v
  return ""

proc add*(p: var Props; n, v: string, overwrite = false, delimiter = ","): var Props {.discardable.} =
  ## Sets the property named ``n`` to the value ``v``. If the property was already set,
  ## then overwrite it's value if ``overwrite`` == `true` or append it using ``delimiter``
  ## to the previous value.
  result = p
  for idx in 0..<p.len:
    var el = getMVar(p, idx)
    if el.name.cmpIgnoreCase(n) == 0:
      if overwrite:
        el.value = v
      else:
        el.value = el.value & delimiter & v
      return
  ((seq[Prop])p).add(prop(n, v))

proc `[]=`*(p: var Props; n, v: string) =
  ## Sets the property ``n`` to the value ``v``.
  p.add(n, v, overwrite = true)

proc contains*(p: Props, name: string): bool =
  ## Checks if the property named ``name`` exists.
  for n, _ in p.pairs:
    if n.cmpIgnoreCase(name) == 0:
      return true

proc newProps*(vals: varargs[tuple[name: string, value: string]], overwrite = false, delimiter = ","): Props =
  ## Creates new properties set filled with ``vals``. Parameters ``overwrite`` and ``delimiter`` works
  ## as in the ``add`` function.
  result = (Props)newSeq[Prop]()
  for el in vals:
    result.add(el.name, el.value, overwrite, delimiter)

proc toSeq*(p: Props): seq[(string, string)] =
  ## Converts properties set ``p`` to the sequence of key/value pairs
  result = newSeq[(string, string)](p.len)
  for idx in 0..<p.len:
    let el = ((seq[Prop])p)[idx]
    result[idx] = (el.name, el.value)

proc clear*(p: var Props) =
  ## Clears mutable properties set ``p``
  ((seq[Prop])p).setLen(0)

proc isNil*(p: Props): bool =
  ## Checks 
  ((seq[Prop])p).isNil

proc toStringTable*(p: Props, t: StringTableRef) =
  for k, v in p.pairs:
    t[k] = v

proc asStringTable*(p: Props): StringTableRef =
  result = newStringTable(modeCaseInsensitive)
  p.toStringTable(result)

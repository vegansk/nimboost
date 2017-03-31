import json, strutils, algorithm, boost.parsers

type
  FieldException* = object of Exception
    path: seq[string]

proc newFieldException*(msg: string, path: seq[string] = @[]): ref FieldException =
  new result
  result.msg = msg
  result.path = path

proc getPath*(e: ref FieldException): string =
  e.path.reversed.join(".")

proc addPath*(e: ref FieldException, p: string) =
  e.path.add(p)

proc fromJson*(_: typedesc[string], n: JsonNode): string =
  if n == nil:
    raise newFieldException("Can't get field of type string")
  else:
    return n.getStr

proc fromJson*(_: typedesc[int], n: JsonNode): int =
  if n == nil:
    raise newFieldException("Can't get field of type int")
  else:
    return n.getNum.int

proc fromJson*[T: enum](_: typedesc[T], n: JsonNode): T =
  parsers.parseEnum[T](n.getStr)

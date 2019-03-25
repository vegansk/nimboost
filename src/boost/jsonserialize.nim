import json, strutils, algorithm, boost/parsers

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

proc toJson*(v: string): JsonNode =
  newJString(v)

proc fromJson*(_: typedesc[int], n: JsonNode): int =
  if n == nil:
    raise newFieldException("Can't get field of type int")
  else:
    return n.getInt

proc toJson*(v: int): JsonNode =
  newJInt(v)

proc fromJson*[T: enum](_: typedesc[T], n: JsonNode): T =
  parsers.parseEnum[T](n.getStr)

proc toJson*[T: enum](v: T): JsonNode =
  ($v).toJson

proc fromJson*(_: typedesc[JsonNode], n: JsonNode): JsonNode =
  n

proc toJson*(n: JsonNode): JsonNode =
  n

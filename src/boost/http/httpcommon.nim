import strutils, strtabs, ../data/props, parseutils, asyncdispatch, ../io/asyncstreams

## Module provides helper functions for HTTP protocol implementations

proc urlEncode*(s: string): string =
  ## Encodes ``s`` to be `application/x-www-form-urlencoded` compilant
  result = newStringOfCap(s.len)
  for ch in s:
    case ch
    of 'a'..'z', 'A'..'Z', '0'..'9', '_':
      result.add(ch)
    of ' ':
      result.add('+')
    else:
      result.add('%')
      result.add(ord(ch).toHex(2))

proc urlDecode*(s: string): string =
  ## Decodes ``s`` from `application/x-www-form-urlencoded` compilant form
  result = newStringOfCap(s.len)
  var i = 0
  while i < s.len:
    let ch = s[i]
    case ch
    of '%':
      result.add(chr(parseHexInt(s[i+1..i+2])))
      i += 2
    of '+':
      result.add(' ')
    else:
      result.add(ch)
    inc i

proc formEncode*(form: Props): string =
  ## Encodes ``form`` to `application/x-www-form-urlencoded` format
  for k, v in form.pairs:
    let s = urlEncode(k) & "=" & urlEncode(v)
    if result.isNil:
      result = s
    else:
      result &= "&" & s

proc formDecode*(data: string, form: var Props) =
  ## Decodes ``data`` from `application/x-www-form-urlencoded` format into ``form``
  if form.isNil:
    form = newProps()
  else:
    form.clear
  for line in data.split('&'):
    let kv = line.split('=')
    if kv.len != 2:
      raise newException(ValueError, "Malformed form data")
    form[urlDecode(kv[0])] = urlDecode(kv[1])

proc formDecode*(data: string): Props =
  ## Decodes ``data`` from `application/x-www-form-urlencoded` format
  data.formDecode(result)

proc parseHeader*(line: string): (string, string) =
  ## Parses one header from ``line`` into key/value tuple
  var idx = line.skipWhitespace
  idx += line.parseUntil(result[0], ':', idx) + 1
  idx += line.skipWhitespace(idx)
  result[1] = line[idx..^1]

proc readHeaders*(s: AsyncStream): Future[Props] {.async.} =
  ## Reads http headers from the stream ``s``
  result = newProps()
  var prevLine = ""
  while true:
    let line = await s.readLine
    if line == "":
      break
    if line[0] == ' ' or line[0] == '\t':
      prevLine.add(line[line.skipWhitespace..^1])
    else:
      if prevLine != "":
        let (k, v) = prevLine.parseHeader
        result.add(k, v)
      prevLine = line
  if prevLine != "":
    let (k, v) = prevLine.parseHeader
    result.add(k, v)

proc parseCHeader(value: string): (string, seq[(string, string)]) =
  result[0] = ""
  result[1] = newSeq[(string, string)]()
  var idx = 0
  idx += value.skipWhitespace()
  idx += value.parseUntil(result[0], ';', idx) + 1
  while idx < value.len:
    idx += value.skipWhitespace(idx)
    var k = ""
    var v = ""
    idx += value.parseUntil(k, '=', idx) + 1
    idx += value.parseUntil(v, ';', idx) + 1
    result[1].add((k, v))

type
  ContentType* = object
    ## Structure describing `Content-Type` header
    mimeType*: string
    charset*: string
    boundary*: string

proc parseContentType*(value: string): ContentType =
  ## Parses the ``value`` of `Content-Type` header
  let (mt, rest) = value.parseCHeader
  result.mimeType = mt
  for h in rest:
    case h[0]
    of "charset":
      result.charset = h[1]
    of "boundary":
      result.boundary = h[1]

proc `$`*(ct: ContentType): string =
  ## Forms the `Content-Type` value
  result = ct.mimeType
  if ct.charset.len > 0:
    result &= "; charset=" & ct.charset
  if ct.boundary.len > 0:
    result &= "; boundary=" & ct.boundary

type
  ContentDisposition* = object
    ## Structure describing `Content-Disposition` header
    disposition*: string
    name*: string
    filename*: string
    size*: int64

proc parseContentDisposition*(value: string): ContentDisposition =
  ## Parses the ``value`` of `Content-Disposition` header

  proc quotedString(s: string): string =
    if s.len < 2 or s[0] != '"' or s[^1] != '"':
      raise newException(ValueError, "Malformed Content-Disposition")
    s[1..^2]

  proc token(s: string): string =
    if s.len < 1:
      raise newException(ValueError, "Malformed Content-Disposition")
    s

  proc extValue(s: string): string =
    if s.len > 0 and s[0] == '"':
      quotedString(s)
    else:
      token(s)

  result.size = -1
  let (d, rest) = value.parseCHeader
  result.disposition = d
  for h in rest:
    case h[0]
    of "name":
      result.name = extValue(h[1])
    of "filename":
      # filename MUST be quoted
      result.filename = quotedString(h[1])
    of "size":
      result.size = extValue(h[1]).parseBiggestInt

proc `$`*(cd: ContentDisposition): string =
  ## Forms the `Content-Disposition` value
  result = cd.disposition
  if cd.name.len > 0:
    result &= "; name=" & cd.name
  if cd.filename.len > 0:
    result &= "; filename=" & cd.filename
  if cd.size > 0:
    result &= "; size=" & $cd.size

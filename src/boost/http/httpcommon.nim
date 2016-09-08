import strutils, strtabs, boost.data.props

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

## Module provides string utilities

import parseutils, sequtils, macros, strutils, ./formatters, ./parsers

proc parseIntFmt(fmtp: string): tuple[maxLen: int, fillChar: char] =
  var maxLen = if fmtp == "": 0 else: strToInt(fmtp)
  var minus = fmtp.len > 0 and fmtp[0] == '-'
  var fillChar = if ((minus and fmtp.len > 1) or fmtp.len > 0) and fmtp[if minus: 1 else: 0] == '0': '0' else: ' '
  (maxLen, fillChar)

proc parseFloatFmt(fmtp: string): tuple[maxLen: int, prec: int, fillChar: char] =
  result.fillChar = ' '
  if fmtp == "":
    return
  var t = ""
  var minus = 1
  var idx = 0
  idx += fmtp.parseWhile(t, {'-'}, idx)
  if t == "-":
    minus = -1
  idx += fmtp.parseWhile(t, {'0'}, idx)
  if t == "0":
    result.fillChar = '0'
  idx += fmtp.parseWhile(t, {'0'..'9'}, idx)
  if t != "":
    result.maxLen = minus * strToInt(t)
  idx += fmtp.skipWhile({'.'}, idx)
  idx += fmtp.parseWhile(t, {'0'..'9'}, idx)
  if t != "":
    result.prec = strToInt(t)

proc handleIntFormat(exp: string, fmtp: string, radix: int): NimNode {.compileTime.} =
  let (maxLen, fillChar) = parseIntFmt(fmtp)
  result = newCall(bindSym"intToStr", parseExpr(exp), newLit(radix), newLit(maxLen), newLit(fillChar))

proc handleDFormat(exp: string, fmtp: string): NimNode {.compileTime.} =
  result = handleIntFormat(exp, fmtp, 10)

proc handleXFormat(exp: string, fmtp: string): NimNode {.compileTime.} =
  result = handleIntFormat(exp, fmtp, 16)

proc handleFFormat(exp: string, fmtp: string): NimNode {.compileTime.} =
  var (maxLen, prec, fillChar) = parseFloatFmt(fmtp)
  result = newCall(bindSym"floatToStr", parseExpr(exp), newLit(maxLen), newLit(prec), newLit('.'), newLit(fillChar), newLit(false))

proc handleEFormat(exp: string, fmtp: string): NimNode {.compileTime.} =
  var (maxLen, prec, fillChar) = parseFloatFmt(fmtp)
  result = newCall(bindSym"floatToStr", parseExpr(exp), newLit(maxLen), newLit(prec), newLit('.'), newLit(fillChar), newLit(true))

proc handleSFormat(exp: string, fmtp: string): NimNode {.compileTime.} =
  var (maxLen, _) = parseIntFmt(fmtp)
  if maxLen == 0:
    result = parseExpr("$(" & exp & ")")
  else:
    result = newCall(bindSym"alignStr", parseExpr("$(" & exp & ")"), newLit(maxLen), newLit(' '))

proc handleFormat(exp: string, fmt: string, nodes: var seq[NimNode]) {.compileTime} =
  if fmt[1] == '%':
    nodes.add(parseExpr("$(" & exp & ")"))
    nodes.add(newLit(fmt[1..^1]))
  else:
    const formats = {'d', 'f', 's', 'x', 'e'}
    var idx = 1
    var fmtm = ""
    var fmtp = ""
    while idx < fmt.len:
      if fmt[idx].isAlpha:
        if fmt[idx] in formats:
          fmtm = $fmt[idx]
          fmtp = fmt[1..idx-1]
        break
      inc idx
    if fmtm == "":
      nodes.add(parseExpr("$(" & exp & ")"))
      nodes.add(newLit(fmt))
    else:
      case fmtm
      of "d":
        nodes.add(handleDFormat(exp, fmtp))
      of "x":
        nodes.add(handleXFormat(exp, fmtp))
      of "f":
        nodes.add(handleFFormat(exp, fmtp))
      of "e":
        nodes.add(handleEFormat(exp, fmtp))
      of "s":
        nodes.add(handleSFormat(exp, fmtp))
      else:
        quit "Unknown format \"" & fmtm & "\""
      nodes.add(newLit(fmt[idx+1..^1]))

macro fmt*(fmt: static[string]): expr =
  ## String interpolation macro with scala-like format specifiers.
  ## Knows about:
  ## * `d` - decimal number formatter
  ## * `h` - hex number formatter
  ## * `f` - float number formatter
  ## * `e` - float number formatter (scientific form)
  ## * `s` - string formatter
  ##
  ## Examples:
  ##
  ## .. code-block:: Nim
  ##
  ##   import boost.richstring
  ##
  ##   let s = "string"
  ##   assert fmt"${s[0..2].toUpper}" == "STR"
  ##   assert fmt"${-10}%04d" == "-010"
  ##   assert fmt"0x${10}%02x" == "0x0A"
  ##   assert fmt"""${"test"}%-5s""" == "test "
  ##   assert fmt"${1}%.3f" == "1.000"
  ##   assert fmt"Hello, $s!" == "Hello, string!"

  proc esc(s: string): string {.inline.} =
    result = newStringOfCap(s.len)
    for ch in s.replace("\xD\xA", "\\n").replace("\xA\xD", "\n"):
      case ch
      of '\xD':
        result.add("\\n")
      of '\xA':
        result.add("\\n")
      of '\"':
        result.add("\\\"")
      else:
        result.add(ch)

  var nodes: seq[NimNode] = @[]
  var fragments = toSeq(fmt.interpolatedFragments)
  for idx in 0..<fragments.len:
    let k = fragments[idx][0]
    let v = fragments[idx][1]
    case k
    of ikDollar:
      nodes.add(newLit(v))
    of ikStr:
      if v[0] == '%' and v.len > 1 and idx > 0 and fragments[idx-1][0] in {ikVar, ikExpr}:
        nodes.del(nodes.len-1)
        handleFormat(fragments[idx-1][1], v, nodes)
      else:
        nodes.add(parseExpr("\"" & v.esc & "\""))
    else:
      nodes.add(parseExpr("$(" & v & ")"))
  result = newNimNode(nnkStmtList).add(
    foldr(nodes, a.infix("&", b)))

import strutils, asyncdispatch
import ../io/asyncstreams
import ./httpcommon

type
  # Possible states of the stream:
  # 1. Beginning of a chunk (bytesLeft = 0).
  #    Underlying stream will next read the first byte of the next chunk size.
  # 2. Middle of a chunk (bytesLeft > 0).
  #    Underlying stream will next read one of the bytes of chunk data.
  # 3. EOF. No more data to read
  # 4. Closed.
  State = enum sBeginning, sMiddle, sEOF, sFailed, sClosed
  AsyncChunkedStream* = ref AsyncChunkedStreamObj
    ## Asynchronous chunked stream.
    ##
    ## Decodes the underlying stream from `Transfer-Encoding: chunked`.
    ##
  AsyncChunkedStreamObj* = object of AsyncStreamObj
    ## Asynchronous chunked stream.
    src: AsyncStream
    state: State
    bytesLeft: Natural # until the end of the current chunk

proc isFailed*(s: AsyncChunkedStream): bool =
  ## Returns `true` if parsing the message body has failed.
  s.state == sFailed

proc cClose(s: AsyncStream) =
  if s.AsyncChunkedStream.state in {sBeginning, sMiddle, sEOF, sFailed}:
    s.AsyncChunkedStream.src.close

  # Make sure not to lose `sFailed` state
  s.AsyncChunkedStream.state = min(sClosed, s.AsyncChunkedStream.state)

proc cAtEnd(s: AsyncStream): bool =
  s.AsyncChunkedStream.state in {sEOF, sClosed, sFailed}

proc raiseError(s: AsyncChunkedStream, msg: string) {.noReturn.} =
  s.state = sFailed
  raise newException(MalformedHttpException, msg)

proc readExactly(s: AsyncChunkedStream, size: Natural): Future[string] {.async.} =
  var res = newString(size)
  var pos = 0
  while pos < size:
    let bytesRead = await s.src.readBuffer(addr(res[pos]), size - pos)
    if bytesRead <= 0: raiseError(s, "unexpected EOF")
    pos.inc(bytesRead)
  return res

proc readExpected(
  s: AsyncChunkedStream,
  expected: string,
  description: string = nil
): Future[void] {.async.} =
  let got = await s.readExactly(expected.len)
  if expected != got:
    let effectiveDesc = if description.isNil: escape(expected) else: description
    raiseError(s, effectiveDesc & " expected, got " & escape(got))

proc readHttpLine(s: AsyncChunkedStream): Future[string] {.async.} =
  ## Like `src.readLine`, but the line must terminate in `"\c\l"`. The ending
  ## sequence itself is not a part of the resulting string. `'\0'` in the line
  ## is allowed.
  var res = ""
  while true:
    let c = await s.src.readChar
    if c == '\c':
      await s.readExpected("\L")
      # Found newline
      break
    elif c == '\L':
      raiseError(s, "unexpected \\L")
    elif c == '\0' and s.src.atEnd:
      raiseError(s, "unexpected EOF")
    else:
      res.add(c)

  return res

proc readNewline(s: AsyncChunkedStream): Future[void] {.async.} =
  await s.readExpected("\c\l")

proc readSizeAndExtensions(s: AsyncChunkedStream): Future[Natural] {.async.} =
  let line = await s.readHttpLine
  let sepPos = line.find(';')
  let sub =
    if sepPos == -1: line
    else: line[0..<sepPos]

  var res: int
  try:
    # TODO: don't allow hex prefices
    res = parseHexInt(sub)
    if res < 0: s.raiseError("invalid chunk size: " & escape(sub))
  except ValueError:
    s.raiseError("invalid chunk size: " & escape(sub))

  return res.Natural

proc readTrailer(s: AsyncChunkedStream): Future[void] {.async.} =
  while (await s.readHttpLine) != "": discard

proc cRead(s0: AsyncStream, buf: pointer, bufLen: int): Future[int] {.async.} =
  let s = s0.AsyncChunkedStream
  if bufLen <= 0 or s.state in {sEOF, sClosed}: return 0
  if s.state == sFailed: s.raiseError("Malformed message body")

  if s.state == sBeginning:
    s.bytesLeft = await readSizeAndExtensions(s)

    if s.bytesLeft == 0:
      # The last part
      await readTrailer(s)
      s.state = sEOF
      return 0
    else:
      s.state = sMiddle

  # We're in the middle of a nonempty chunk
  let bytesToRead = min(bufLen, s.bytesLeft)
  let bytesRead = await s.src.readBuffer(buf, bytesToRead)
  if bytesRead <= 0:
    s.raiseError("unexpected EOF")
  # This also proves that `bytesRead <= s.bytesLeft`
  if bytesRead > bytesToRead:
    s.raiseError("read more bytes than requested")

  s.bytesLeft -= bytesRead

  if s.bytesLeft == 0:
    # We're at the end of a non-empty chunk - read up to the next one
    await readNewline(s)
    s.state = sBeginning
  else:
    # We're still in the middle
    s.state = sMiddle

  return bytesRead

proc newAsyncChunkedStream*(src: AsyncStream): AsyncChunkedStream =
  ## Create a new chunked stream wrapper.
  ##
  ## Decodes `Transfer-Encoding: chunked` message body in the underlying stream.
  ##
  ## The underlying stream must be at the first byte of the first chunk's size.
  ## Unless an error is raised, after reading all the data from decoded stream
  ## the underlying stream is positioned at the first byte after the decoded
  ## message body. Closing the underlying stream is handled by caller to allow
  ## continuing HTTP connection.
  ##
  ## Decoded stream can throw a `MalformedHttpException` when
  ## reading or closing to signal unexpected data in the underlying stream.
  ##
  ## *Warning*: Discarding or closing the chunked stream before it reaches the
  ## end will leave the underlying connection in the middle of the message body,
  ## rendering it unusable.
  new result
  result.src = src
  result.state = sBeginning
  result.bytesLeft = 0
  # TODO: these casts are ugly. Does it even make sense to have effect tracking
  # for async procs, if they have `RootEffect` by default?
  result.closeImpl = cast[type(result.closeImpl)](cClose)
  result.atEndImpl = cast[type(result.atEndImpl)](cAtEnd)
  result.readImpl = cast[type(result.readImpl)](cRead)

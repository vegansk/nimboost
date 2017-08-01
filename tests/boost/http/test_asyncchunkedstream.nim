import asyncdispatch, unittest, strutils, random, sequtils, future
import boost.io.asyncstreams, boost.http.asyncchunkedstream

const allChars: seq[char] = toSeq('\0'..'\255')
const allCharsExceptNewline = allChars.filter(t => t notIn {'\c', '\L'})

type
  # Restricts `readImpl` to read 1 to `maxBytesRead` bytes per call
  ThrottleStream = ref ThrottleStreamObj
  ThrottleStreamObj = object of AsyncStream
    src: AsyncStream
    maxBytesRead: Natural

proc tRead(s: AsyncStream, buf: pointer, size0: int): Future[int] {.gcsafe.} =
  let size = random(1..min(size0, s.ThrottleStream.maxBytesRead).succ)
  s.ThrottleStream.src.readBuffer(buf, size)

proc newThrottleStream(
  input: AsyncStream,
  maxBytesRead: Natural = 4
): ThrottleStream =
  new result
  result.src = input
  wrapAsyncStream(ThrottleStream, src)

  result.maxBytesRead = maxBytesRead
  result.readImpl = cast[type(result.readImpl)](tRead)

proc randomBool(p: float = 0.5): bool = random(1.0) < p

proc randomString(size: Natural, chars: openarray[char] = allChars): string =
  result = newString(size)
  for i in 0..<size:
    result[i] = random(chars)

proc genChunked(): tuple[data: string, encoded: string] =
  let numChunks = random(3)
  var data = ""
  var encoded = ""
  for chunkIdx in 0..<numChunks:
    let size = random(1..100)
    let chunk = randomString(size)
    data.add(chunk)

    var sizeStr = toHex(size)
    trimZeros(sizeStr)
    sizeStr = repeat('0', random(3)) & sizeStr

    encoded.add(sizeStr)
    if randomBool():
      let extension = randomString(random(20), allCharsExceptNewline)
      encoded.add(";")
      encoded.add(extension)

    encoded.add("\c\L")
    encoded.add(chunk)
    encoded.add("\c\L")

  encoded.add(repeat('0', random(1..10)))
  if randomBool():
    let extension = randomString(random(20), allCharsExceptNewline)
    encoded.add(";")
    encoded.add(extension)

  encoded.add("\c\L")

  let trailerLines = random(1..3)
  for i in 0..<trailerLines:
    encoded.add(randomString(random(1..100), allCharsExceptNewline))
    encoded.add("\c\L")

  encoded.add("\c\L")

  (data, encoded)

suite "AsyncChunkedStream":
  test "should work with a simple example":
    let encoded = "4\c\LWiki\c\L5\c\Lpedia\c\LE\c\L in\c\L\c\Lchunks.\c\L0\c\L\c\L"
    let input = newAsyncStringStream(encoded)
    let wrapped = newAsyncChunkedStream(input)
    defer: wrapped.close()
    let decoded = waitFor(wrapped.readAll)
    check: decoded == "Wikipedia in\c\L\c\Lchunks."

  test "should close the underlying stream":
    let input = newAsyncStringStream("0\c\L\c\Lremainder")
    let wrapped = newAsyncChunkedStream(input)

    check: waitFor(wrapped.readAll) == ""
    check: wrapped.atEnd
    check: not input.atEnd

    wrapped.close()
    check: wrapped.atEnd
    check: input.atEnd

  test "should close the underlying stream even after malformed data":
    let input = newAsyncStringStream("this\c\Lis not valid")
    let wrapped = newAsyncChunkedStream(input)

    expect(MalformedChunkedStreamError) do:
      discard waitFor(wrapped.readData(10))

    check: wrapped.atEnd
    check: not input.atEnd

    wrapped.close()
    check: wrapped.atEnd
    check: input.atEnd

  test "should work with randomized examples":
    # TODO: it might be useful to check some specific conditions first
    for iteration in 1..100:
      let (data, encoded) = genChunked()
      let expectedLeftover = randomString(10)
      let inputString = encoded & expectedLeftover
      let input = newAsyncStringStream(inputString)
      let wrapped = newAsyncChunkedStream(input)
      defer: wrapped.close()

      try:
        let decoded = waitFor(wrapped.readAll)
        check: decoded == data
      except:
        echo "data (", data.len, " bytes): \L", escape(data)
        echo "input string (", inputString.len, " bytes): \L", escape(inputString)
        echo "position: ", input.getPosition
        raise

      let leftover = waitFor(input.readAll)
      check: leftover == expectedLeftover

  test "should work with partial reads":
    # Stream parsers can be brittle in case of partial reads.
    for iteration in 1..100:
      let (data, encoded) = genChunked()
      let expectedLeftover = randomString(10)
      let inputString = encoded & expectedLeftover
      let input = newThrottleStream(newAsyncStringStream(inputString))
      let wrapped = newAsyncChunkedStream(input)
      defer: wrapped.close()

      try:
        let decoded = waitFor(wrapped.readAll)
        check: decoded == data
      except:
        echo "data (", data.len, " bytes): \L", escape(data)
        echo "input string (", inputString.len, " bytes): \L", escape(inputString)
        echo "position: ", input.getPosition
        raise

      let leftover = waitFor(input.readAll)
      check: leftover == expectedLeftover

  test "should fail for truncated randomized examples":
    for iteration in 1..100:
      let (data, encoded) = genChunked()
      # make sure at least one byte is truncated
      let inputString = encoded[0..<random(0..<encoded.len)]
      let input = newAsyncStringStream(inputString)
      let wrapped = newAsyncChunkedStream(input)
      defer: wrapped.close()

      expect(MalformedChunkedStreamError) do:
        discard waitFor(wrapped.readAll)

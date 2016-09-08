#
#
#            Nim's Runtime Library
#        (c) Copyright 2016 Anatoly Galiulin
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

import asyncdispatch, asyncnet, asyncfile

## This module provides the asynchronous stream interface and some of the implementations
## including ``AsyncStringStream``, ``AsyncFileStream`` and ``AsyncSocketStream``.
##
## If you want to implement your own asynchronous stream, you must provide the
## implementations of the streams operations as defined in ``AsyncStreamObj``.
## Also, you can use some helpers for the absent operations, like ``setPositionNotImplemented``,
## ``flushNop``, etc.
##
## Example:
##
## .. code-block:: Nim
##
##  import asyncdispatch, asyncstreams, strutils
##
##  proc main {.async.} =
##    var s = newAsyncStringStream("""Hello
##  world!""")
##    var res = newSeq[string]()
##    while true:
##      let l = await s.readLine()
##      if l == "":
##        break
##      res.add(l)
##    doAssert(res.join(", ") == "Hello, world!")
##  waitFor main()

type
  AsyncStream* = ref AsyncStreamObj
  AsyncStreamObj* = object of RootObj ## Asychronous stream interface.
    closeImpl*: proc (s: AsyncStream) {.nimcall, tags:[], gcsafe.}
    atEndImpl*: proc (s: AsyncStream): bool {.nimcall, tags:[], gcsafe.}
    setPositionImpl*: proc (s: AsyncStream; pos: int64) {.nimcall, tags:[], gcsafe.}
    getPositionImpl*: proc (s: AsyncStream): int64 {.nimcall, tags:[], gcsafe.}
    readImpl*: proc (s: AsyncStream; buf: pointer, size: int): Future[int] {.nimcall, tags: [ReadIOEffect], gcsafe.}
    peekImpl*: proc (s: AsyncStream; buf: pointer, size: int): Future[int] {.nimcall, tags: [ReadIOEffect], gcsafe.}
    peekLineImpl*: proc (s: AsyncStream): Future[string] {.nimcall, tags: [ReadIOEffect], gcsafe.}
    writeImpl*: proc (s: AsyncStream; buf: pointer, size: int): Future[void] {.nimcall, tags: [WriteIOEffect], gcsafe.}
    flushImpl*: proc (s: AsyncStream): Future[void] {.nimcall, tags:[], gcsafe.}

#[
# ``Not implemented`` stuff
]#

template atEndNotImplemented =
  raise newException(IOError, "atEnd operation is not implemented")

template setPositionNotImplemented =
  raise newException(IOError, "setPosition operation is not implemented")

template getPositionNotImplemented =
  raise newException(IOError, "getPosition operation is not implemented")

template readNotImplemented =
  raise newException(IOError, "read operation is not implemented")

template peekNotImplemented =
  raise newException(IOError, "peek operation is not implemented")

template writeNotImplemented =
  raise newException(IOError, "write operation is not implemented")

template flushNotImplemented =
  if true: # Workaround for ``Error: statement not allowed after 'return', 'break', 'raise' or 'continue'``
    raise newException(IOError, "flush operation is not implemented")

proc flushNop(s: AsyncStream) {.async.} =
  discard

#[
# AsyncStream
]#

proc flush*(s: AsyncStream) {.async.} =
  ## Flushes the buffers of the stream ``s``.
  if s.flushImpl.isNil:
    flushNotImplemented
  await s.flushImpl(s)

proc close*(s: AsyncStream) =
  ## Closes the stream ``s``.
  s.closeImpl(s)

proc atEnd*(s: AsyncStream): bool =
  ## Checks if all data has been read from the stream ``s``
  if s.atEndImpl.isNil:
    atEndNotImplemented
  s.atEndImpl(s)

proc getPosition*(s: AsyncStream): int64 =
  ## Retrieves the current position in the stream ``s``
  if s.getPositionImpl.isNil:
    getPositionNotImplemented
  s.getPositionImpl(s)

proc setPosition*(s: AsyncStream, pos: int64) =
  ## Sets the current position in the stream ``s``
  if s.setPositionImpl.isNil:
    setPositionNotImplemented
  s.setPositionImpl(s, pos)

proc readBuffer*(s: AsyncStream, buffer: pointer, size: int): Future[int] {.async.} =
  ## Reads up to ``size`` bytes from the stream ``s`` into the ``buffer`` 
  if s.readImpl.isNil:
    readNotImplemented
  result = await s.readImpl(s, buffer, size)

proc peekBuffer*(s: AsyncStream, buffer: pointer, size: int): Future[int] {.async.} =
  ## Reads up to ``size`` bytes from the stream ``s`` into the ``buffer`` without moving
  ## stream position
  if s.peekImpl.isNil:
    if not s.getPositionImpl.isNil and not s.setPositionImpl.isNil:
      let pos = s.getPosition
      result = await s.readBuffer(buffer, size)
      s.setPosition(pos)
    else:
      peekNotImplemented
  result = await s.peekImpl(s, buffer, size)

proc writeBuffer*(s: AsyncStream, buffer: pointer, size: int) {.async.} =
  ## Writes ``size`` bytes from the ``buffer`` into the stream ``s``
  if s.writeImpl.isNil:
    writeNotImplemented
  await s.writeImpl(s, buffer, size)

proc readData*(s: AsyncStream, size: int): Future[string] {.async.} =
  ## Reads up to the ``size`` bytes into the string from the stream ``s``
  result = newString(size)
  let readed = await s.readBuffer(result.cstring, size)
  result.setLen(readed)

proc writeData*(s: AsyncStream, data: string) {.async.} =
  ## Writes ``data`` to the stream ``s``
  await s.writeBuffer(data.cstring, data.len)

proc readChar*(s: AsyncStream): Future[char] {.async.} =
  ## Reads the char from the stream ``s``
  let data = await s.readData(1)
  result = if data.len == 0: '\0' else: data[0]

proc peekChar*(s: AsyncStream): Future[char] {.async.} =
  ## Peeks the char from the stream ``s``
  let data = await s.readData(1)
  result = if data.len == 0: '\0' else: data[0]

proc writeChar*(s: AsyncStream, c: char) {.async.} =
  ## Writes the char to the stream ``s``
  await s.writeData($c)

proc readLine*(s: AsyncStream): Future[string] {.async.} =
  ## Reads the line from the stream ``s`` until end of stream or the new line delimeter
  result = ""
  while true:
    let c = await s.readChar
    if c == '\c':
      await s.readChar
      break
    elif c == '\L' or c == '\0':
      break
    else:
      result.add(c)

proc peekLine*(s: AsyncStream): Future[string] {.async.} =
  ## Peeks the line from the stream ``s`` until end of stream or the new line delimeter.
  ## It works only if the stream supports peekLine operation itself or
  ## allows to get/set stream position
  if not s.peekLineImpl.isNil:
    result = await s.peekLineImpl(s)
  else:
    let pos = s.getPosition
    result = await s.readLine
    s.setPosition(pos)

proc writeLine*(s: AsyncStream, data: string) {.async.} =
  ## Writes the line from the stream ``s`` followed by the new line delimeter
  await s.writeData(data & "\n")

proc readAll*(s: AsyncStream): Future[string] {.async.} =
  ## Reads the data from the stream ``s`` until it's end
  result = ""
  while not s.atEnd:
    result &= await s.readData(4096)

template checkEof(res: untyped): untyped =
  if not res:
    raise newException(IOError, "End of file exception")

proc readByte*(s: AsyncStream): Future[byte] {.async.} =
  ## Reads byte from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekByte*(s: AsyncStream): Future[byte] {.async.} =
  ## Peeks byte from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeByte*(s: AsyncStream, data: byte) {.async.} =
  ## Writes byte to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt8*(s: AsyncStream): Future[int8] {.async.} =
  ## Reads int8 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekInt8*(s: AsyncStream): Future[int8] {.async.} =
  ## Peeks int8 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt8*(s: AsyncStream, data: int8) {.async.} =
  ## Writes int8 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt16*(s: AsyncStream): Future[int16] {.async.} =
  ## Reads int16 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekInt16*(s: AsyncStream): Future[int16] {.async.} =
  ## Peeks int16 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt16*(s: AsyncStream, data: int16) {.async.} =
  ## Writes int16 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt32*(s: AsyncStream): Future[int32] {.async.} =
  ## Reads int32 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekInt32*(s: AsyncStream): Future[int32] {.async.} =
  ## Peeks int32 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt32*(s: AsyncStream, data: int32) {.async.} =
  ## Writes int32 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt64*(s: AsyncStream): Future[int64] {.async.} =
  ## Reads int64 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekInt64*(s: AsyncStream): Future[int64] {.async.} =
  ## Peeks int64 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt64*(s: AsyncStream, data: int64) {.async.} =
  ## Writes int64 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt8*(s: AsyncStream): Future[uint8] {.async.} =
  ## Reads uint8 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekUInt8*(s: AsyncStream): Future[uint8] {.async.} =
  ## Peeks uint8 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt8*(s: AsyncStream, data: uint8) {.async.} =
  ## Writes uint8 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt16*(s: AsyncStream): Future[uint16] {.async.} =
  ## Reads uint16 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekUInt16*(s: AsyncStream): Future[uint16] {.async.} =
  ## Peeks uint16 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt16*(s: AsyncStream, data: uint16) {.async.} =
  ## Writes uint16 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt32*(s: AsyncStream): Future[uint32] {.async.} =
  ## Reads uint32 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekUInt32*(s: AsyncStream): Future[uint32] {.async.} =
  ## Peeks uint32 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt32*(s: AsyncStream, data: uint32) {.async.} =
  ## Writes uint32 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt64*(s: AsyncStream): Future[uint64] {.async.} =
  ## Reads uint64 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekUInt64*(s: AsyncStream): Future[uint64] {.async.} =
  ## Peeks uint64 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt64*(s: AsyncStream, data: uint64) {.async.} =
  ## Writes uint64 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt*(s: AsyncStream): Future[int] {.async.} =
  ## Reads int from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekInt*(s: AsyncStream): Future[int] {.async.} =
  ## Peeks int from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt*(s: AsyncStream, data: int) {.async.} =
  ## Writes int to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt*(s: AsyncStream): Future[uint] {.async.} =
  ## Reads uint from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekUInt*(s: AsyncStream): Future[uint] {.async.} =
  ## Peeks uint from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt*(s: AsyncStream, data: uint) {.async.} =
  ## Writes uint to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readFloat32*(s: AsyncStream): Future[float32] {.async.} =
  ## Reads float32 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekFloat32*(s: AsyncStream): Future[float32] {.async.} =
  ## Peeks float32 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeFloat32*(s: AsyncStream, data: float32) {.async.} =
  ## Writes float32 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readFloat64*(s: AsyncStream): Future[float64] {.async.} =
  ## Reads float64 from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekFloat64*(s: AsyncStream): Future[float64] {.async.} =
  ## Peeks float64 from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeFloat64*(s: AsyncStream, data: float64) {.async.} =
  ## Writes float64 to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readFloat*(s: AsyncStream): Future[float] {.async.} =
  ## Reads float from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekFloat*(s: AsyncStream): Future[float] {.async.} =
  ## Peeks float from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeFloat*(s: AsyncStream, data: float) {.async.} =
  ## Writes float to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readBool*(s: AsyncStream): Future[bool] {.async.} =
  ## Reads bool from the stream ``s``
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc peekBool*(s: AsyncStream): Future[bool] {.async.} =
  ## Peeks bool from the stream ``s``
  checkEof((await s.peekBuffer(addr result, sizeof result)) == sizeof result)

proc writeBool*(s: AsyncStream, data: bool) {.async.} =
  ## Writes bool to the stream ``s``
  var d = data
  await s.writeBuffer(addr d, sizeof d)

#[
# AsyncFileStream
]#

type
  AsyncFileStream* = ref AsyncFileStreamObj
  AsyncFileStreamObj* = object of AsyncStreamObj
    f: AsyncFile
    eof: bool
    closed: bool

proc fileClose(s: AsyncStream) =
  let f = AsyncFileStream(s)
  f.f.close
  f.closed = true

proc fileAtEnd(s: AsyncStream): bool =
  let f = AsyncFileStream(s)
  f.closed or f.eof

proc fileSetPosition(s: AsyncStream, pos: int64) =
  AsyncFileStream(s).f.setFilePos(pos)

proc fileGetPosition(s: AsyncStream): int64 =
  AsyncFileStream(s).f.getFilePos

proc fileRead(s: AsyncStream, buf: pointer, size: int): Future[int] {.async.} =
  let f = AsyncFileStream(s)
  result = await f.f.readBuffer(buf, size)
  if result == 0:
    f.eof = true

proc fileWrite(s: AsyncStream; buf: pointer, size: int) {.async.} =
  await AsyncFileStream(s).f.writeBuffer(buf, size)

proc initAsyncFileStreamImpl(res: var AsyncFileStreamObj, f: AsyncFile) =
  res.f = f
  res.closed = false

  res.closeImpl = fileClose
  res.atEndImpl = fileAtEnd
  res.setPositionImpl = fileSetPosition
  res.getPositionImpl = fileGetPosition
  res.readImpl = cast[type(res.readImpl)](fileRead)
  res.writeImpl = cast[type(res.writeImpl)](fileWrite)
  res.flushImpl = cast[type(res.flushImpl)](flushNop)

proc newAsyncFileStream*(fileName: string, mode = fmRead): AsyncStream =
  ## Creates the new AsyncFileStream from the file named ``fileName``
  ## with given ``mode``.
  var res = new AsyncFileStream
  initAsyncFileStreamImpl(res[], openAsync(fileName, mode))
  result = res

proc newAsyncFileStream*(f: AsyncFile): AsyncFileStream =
  ## Creates the new AsyncFileStream from the AsyncFile ``f``.
  var res = new AsyncFileStream
  initAsyncFileStreamImpl(res[], f)
  result = res

#[
# AsyncStringStream
]#

type
  AsyncStringStream* = ref AsyncStringStreamObj
  AsyncStringStreamObj* = object of AsyncStreamObj
    data: string
    pos: int
    eof: bool
    closed: bool

proc strClose(s: AsyncStream) =
  let str = AsyncStringStream(s)
  str.closed = true

proc strAtEnd(s: AsyncStream): bool =
  let str = AsyncStringStream(s)
  str.closed or str.eof

proc strSetPosition(s: AsyncStream, pos: int64) =
  let str = AsyncStringStream(s)
  str.pos = if pos.int > str.data.len: str.data.len else: pos.int

proc strGetPosition(s: AsyncStream): int64 =
  AsyncStringStream(s).pos

proc strRead(s: AsyncStream, buf: pointer, size: int): Future[int] {.async.} =
  let str = AsyncStringStream(s)
  doAssert(not str.closed, "AsyncStringStream is closed")
  result = min(size, str.data.len - str.pos)
  copyMem(buf, addr str.data[str.pos], result)
  str.pos += result
  if result == 0:
    str.eof = true

proc strWrite(s: AsyncStream, buf: pointer, size: int) {.async.} =
  let str = AsyncStringStream(s)
  doAssert(not str.closed, "AsyncStringStream is closed")
  if str.pos + size > str.data.len:
    str.data.setLen(str.pos + size)
  copyMem(addr str.data[str.pos], buf, size)
  str.pos += size

proc `$`*(s: AsyncStringStream): string =
  ## Converts ``s`` to string
  s.data

proc newAsyncStringStream*(data = ""): AsyncStringStream =
  ## Creates AsyncStringStream filled with ``data``
  new result
  result.data = data

  result.closeImpl = strClose
  result.atEndImpl = strAtEnd
  result.setPositionImpl = strSetPosition
  result.getPositionImpl = strGetPosition
  result.readImpl = cast[type(result.readImpl)](strRead)
  result.writeImpl = cast[type(result.writeImpl)](strWrite)
  result.flushImpl = cast[type(result.flushImpl)](flushNop)

#[
# AsyncSocketStream
]#

type
  AsyncSocketStream* = ref AsyncSocketStreamObj
  AsyncSocketStreamObj* = object of AsyncStreamObj
    s: AsyncSocket
    closed: bool

proc sockClose(s: AsyncStream) =
  AsyncSocketStream(s).s.close
  AsyncSocketStream(s).closed = true

proc sockAtEnd(s: AsyncStream): bool =
  AsyncSocketStream(s).closed

proc sockRead(s: AsyncStream, buf: pointer, size: int): Future[int] {.async.} =
  result = await AsyncSocketStream(s).s.recvInto(buf, size)
  if result == 0:
    AsyncSocketStream(s).closed = true

proc sockWrite(s: AsyncStream; buf: pointer, size: int) {.async.} =
  await AsyncSocketStream(s).s.send(buf, size)

proc initAsyncSocketStreamImpl(res: var AsyncSocketStreamObj, s: AsyncSocket) =
  res.s = s
  res.closed = false

  res.closeImpl = sockClose
  res.atEndImpl = sockAtEnd
  res.readImpl = cast[type(res.readImpl)](sockRead)
  res.writeImpl = cast[type(res.writeImpl)](sockWrite)
  res.flushImpl = cast[type(res.flushImpl)](flushNop)

proc newAsyncSocketStream*(s: AsyncSocket): AsyncSocketStream =
  ## Creates new AsyncSocketStream from the AsyncSocket ``s``
  var res = new AsyncSocketStream
  initAsyncSocketStreamImpl(res[], s)
  result = res

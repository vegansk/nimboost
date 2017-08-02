#
#
#            Nim's Runtime Library
#        (c) Copyright 2015 Dominik Picheta
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#

## This module implements a high performance asynchronous HTTP server.
##
## Examples
## --------
##
## This example will create an HTTP server on port 8080. The server will
## respond to all requests with a ``200 OK`` response code and "Hello World"
## as the response body.
##
## .. code-block::nim
##    import asynchttpserver, asyncdispatch
##
##    var server = newAsyncHttpServer()
##    proc cb(req: Request) {.async.} =
##      await req.respond(Http200, "Hello World")
##
##    waitFor server.serve(Port(8080), cb)

import tables, asyncnet, asyncdispatch, parseutils, uri, strutils, options
import ../io/asyncstreams, ./asyncchunkedstream
from ./httpcommon import MalformedHttpException
import httpcore
import logging, ../richstring

export httpcore except parseHeader

# TODO: If it turns out that the decisions that asynchttpserver makes
# explicitly, about whether to close the client sockets or upgrade them are
# wrong, then add a return value which determines what to do for the callback.
# Also, maybe move `client` out of `Request` object and into the args for
# the proc.
type
  TransferEncoding = enum teDefault, teChunked
  RequestBodyKind = enum rbkCached, rbkStreamed

  RequestBody* = ref RequestBodyObj
  RequestBodyObj = object
    ## The request body implemented as asynchronous stream
    case kind: RequestBodyKind
    of rbkCached:
      data: string
    of rbkStreamed:
      stream: AsyncStream
      contentLength: Option[int64]

  Request* = object
    client*: AsyncSocket # TODO: Separate this into a Response object?
    reqMethod*: string
    headers*: HttpHeaders
    protocol*: tuple[orig: string, major, minor: int]
    url*: Uri
    hostname*: string ## The hostname of the client that made the request.
    reqBody*: RequestBody

  AsyncHttpServer* = ref object
    socket: AsyncSocket
    reuseAddr: bool
    reusePort: bool

{.deprecated: [TRequest: Request, PAsyncHttpServer: AsyncHttpServer,
  THttpCode: HttpCode, THttpVersion: HttpVersion].}

proc newAsyncHttpServer*(reuseAddr = true, reusePort = false): AsyncHttpServer =
  ## Creates a new ``AsyncHttpServer`` instance.
  new result
  result.reuseAddr = reuseAddr
  result.reusePort = reusePort

proc len*(body: RequestBody): Option[int64] =
  ## Returns the length of the body if available, otherwise `-1`
  case body.kind
  of rbkCached: body.data.len.int64.some
  of rbkStreamed: body.contentLength

type
  # A stream wrapper that reads at most `length` bytes from the underlying stream
  RequestBodyStream = ref RequestBodyStreamObj
  RequestBodyStreamObj = object of AsyncStreamObj
    s: AsyncStream
    length: int64
    pos: int64

proc rbClose(s: AsyncStream) =
  s.RequestBodyStream.s.close

proc rbAtEnd(s: AsyncStream): bool =
  s.RequestBodyStream.pos + 1 >= s.RequestBodyStream.length
proc rbGetPosition(s: AsyncStream): int64 = s.RequestBodyStream.pos
proc rbReadData(s: AsyncStream, buff: pointer, buffLen: int): Future[int] {.async.} =
  var ss = s.RequestBodyStream
  let toRead = if ss.pos + buffLen > ss.length: ss.length - ss.pos else: buffLen
  # TODO: handle unexpected EOF somehow?
  result = await ss.s.readBuffer(buff, toRead.int)
  ss.pos += result

proc newRequestBodyStream(s: AsyncStream, length: int64): RequestBodyStream =
  new result
  result.s = s
  result.length = length
  result.pos = 0
  result.closeImpl = rbClose
  result.atEndImpl = rbAtEnd
  result.getPositionImpl = rbGetPosition
  result.readImpl = cast[type(result.readImpl)](rbReadData)

proc newSizedRequestBody(s: AsyncStream, contentLength: int64): RequestBody =
  RequestBody(
    kind: rbkStreamed,
    stream: newRequestBodyStream(s, contentLength),
    contentLength: contentLength.some
  )

proc newChunkedRequestBody(s: AsyncStream): RequestBody =
  RequestBody(
    kind: rbkStreamed,
    stream: newAsyncChunkedStream(s),
    contentLength: none(int64)
  )

proc newEmptyRequestBody(): RequestBody =
  RequestBody(kind: rbkCached, data: "")

proc setBodyCache(body: RequestBody, data: string) =
  body[] = RequestBodyObj(kind: rbkCached, data: data)

proc getStream*(body: RequestBody): AsyncStream =
  ## Returns the request's body as asynchronous stream
  ##
  ## The resulting stream can raise `boost.http.util.MalformedHttpException`
  ## in case of malformed request.
  case body.kind
  of rbkCached:
    return newAsyncStringStream(body.data)
  of rbkStreamed:
    return body.stream

proc body*(request: Request): Future[string] {.async.} =
  ## Returns the body of the request as the string.
  ##
  ## The resulting future can raise `boost.http.util.MalformedHttpException`
  ## in case of malformed request.

  if request.reqBody.isNil: return ""
  else:
    case request.reqBody.kind
    of rbkStreamed:
      # this doesn't work if someone has already started reading the stream!
      let data = await request.reqBody.getStream.readAll
      request.reqBody.setBodyCache(data)
      return request.reqBody.data
    of rbkCached:
      return request.reqBody.data

proc addHeaders(msg: var string, headers: HttpHeaders) =
  for k, v in headers:
    msg.add(k & ": " & v & "\c\L")

proc formatHeadersForLog(headers: HttpHeaders, ignored: string): string =
  result = "{"
  var first = true
  for k, v in headers:
    if cmpIgnoreCase(k, ignored) == 0: continue
    if first: first = false else: result.add(", ")
    result.add(fmt"$k: $v")
  result.add("}")

proc requestLogMsg(req: Request): string =
  let meth = req.reqMethod.toUpperAscii
  let headers = formatHeadersForLog(req.headers, "Authorization")
  fmt"Request: ${req.protocol.orig} $meth ${req.url}, $headers"

proc responseLogMsg(req: Request, code: HttpCode, contentLen: int, headers: HttpHeaders): string =
  let meth = req.reqMethod.toUpperAscii
  let headers =
    if headers.isNil: "{:}"
    else: formatHeadersForLog(headers, "WWW-Authenticate")

  fmt"Response @ $meth ${req.url}: $code, $contentLen bytes, $headers"

proc sendHeaders*(req: Request, headers: HttpHeaders): Future[void] =
  ## Sends the specified headers to the requesting client.
  var msg = ""
  addHeaders(msg, headers)
  return req.client.send(msg)

proc respond*(req: Request, code: HttpCode, content: string,
              headers: HttpHeaders = nil): Future[void] =
  ## Responds to the request with the specified ``HttpCode``, headers and
  ## content.
  ##
  ## This procedure will **not** close the client socket.
  debug(responseLogMsg(req, code, content.len, headers))

  var msg = "HTTP/1.1 " & $code & "\c\L"

  if headers != nil:
    msg.addHeaders(headers)
  msg.add("Content-Length: " & $content.len & "\c\L\c\L")
  msg.add(content)
  result = req.client.send(msg)

proc parseProtocol(protocol: string): tuple[orig: string, major, minor: int] =
  var i = protocol.skipIgnoreCase("HTTP/")
  if i != 5:
    raise newException(ValueError, "Invalid request protocol. Got: " &
        protocol)
  result.orig = protocol
  i.inc protocol.parseInt(result.major, i)
  i.inc # Skip .
  i.inc protocol.parseInt(result.minor, i)

proc sendStatus(client: AsyncSocket, status: string): Future[void] =
  client.send("HTTP/1.1 " & status & "\c\L")

proc processOneRequest(
  client: AsyncSocket, address: string,
  callback: proc (request: Request): Future[void] {.closure, gcsafe.}
): Future[bool] {.async.} =
  ## Receives and handles one request.
  ##
  ## Returns `true` if the connection can be reused.
  ##
  ## Any raised exceptions mean that the connection was left in invalid state,
  ## and the calling code must not reuse it.

  var request: Request
  request.url = initUri()
  request.headers = newHttpHeaders()
  var lineFut = newFutureVar[string]("asynchttpserver.processClient")
  lineFut.mget() = newStringOfCap(80)

  # TODO: there a lot of places we `continue` in the middle of the request.
  # TODO: continuing circumvents closing the connection

  # GET /path HTTP/1.1
  # Header: val
  # \n
  request.headers.clear()
  request.reqBody = nil
  request.hostname.shallowCopy(address)
  assert client != nil
  request.client = client

  proc fail(reason = "Bad Request"): Future[void] {.async.} =
    await request.respond(Http400, reason)
    if true: raise newException(MalformedHttpException, reason)

  # We should skip empty lines before the request
  # https://tools.ietf.org/html/rfc7230#section-3.5
  while true:
    lineFut.mget().setLen(0)
    lineFut.clean()
    await client.recvLineInto(lineFut) # TODO: Timeouts.

    if lineFut.mget == "":
      # Can't read - connection is closed.
      return false

    if lineFut.mget != "\c\L":
      break

  # First line - GET /path HTTP/1.1
  var i = 0
  for linePart in lineFut.mget.split(' '):
    case i
    of 0: request.reqMethod.shallowCopy(linePart.normalize)
    of 1: parseUri(linePart, request.url)
    of 2:
      var failed = false
      try:
        request.protocol = parseProtocol(linePart)
      except ValueError:
        failed = true

      if failed: await fail("Invalid request protocol. Got: " & linePart)
    else:
      await fail("Invalid request. Got: " & lineFut.mget)
    inc i

  # Headers
  while true:
    i = 0
    lineFut.mget.setLen(0)
    lineFut.clean()
    await client.recvLineInto(lineFut)

    if lineFut.mget == "":
      client.close(); return false
    if lineFut.mget == "\c\L": break
    let (key, value) = parseHeader(lineFut.mget)
    request.headers[key] = value
    # Ensure the client isn't trying to DoS us.
    if request.headers.len > headerLimit:
      await fail("Too many headers in request")

  debug(requestLogMsg(request))

  if request.reqMethod == "post":
    # Check for Expect header
    if request.headers.hasKey("Expect"):
      if "100-continue" in request.headers["Expect"]:
        await client.sendStatus("100 Continue")
      else:
        await client.sendStatus("417 Expectation Failed")

  # Create body object (if needed)
  # - Parse relevant headers
  var contentLength = none(int64)
  if request.headers.hasKey("Content-Length"):
    var data: int64 = 0
    # TODO: multiple `Content-Length` fields
    if parseBiggestInt(request.headers["Content-Length"], data) == 0:
      # Can't determine the length - unrecoverable (RFC 7230 3.3.3)
      await fail("Invalid Content-Length")
    contentLength = data.some

  var transferEncoding = teDefault
  if request.headers.hasKey("Transfer-Encoding"):
    let value: string = request.headers["Transfer-Encoding"]
    # TODO: multiple encodings
    if value == "chunked": transferEncoding = teChunked
    else:
      # Can't determine the length - unrecoverable (RFC 7230 3.3.3).
      await fail("Unsupported Transfer-Encoding")

  # - Check header combinations, create the body
  #   see RFC7230 3.3.3
  if transferEncoding == teChunked:
    # Content-Length is overriden.
    request.reqBody = newChunkedRequestBody(
      newAsyncSocketStream(client)
    )
  elif contentLength.isSome:
    request.reqBody = newSizedRequestBody(
      newAsyncSocketStream(client),
      contentLength.get
    )
  else:
    # No length or encoding - expecting empty body
    request.reqBody = newEmptyRequestBody()

  case request.reqMethod
  of "get", "post", "head", "put", "delete", "trace", "options",
     "connect", "patch":
    # `await` inside `try` is broken: https://github.com/nim-lang/Nim/issues/2528
    await callback(request)

  else:
    await request.respond(Http400, "Invalid request method. Got: " &
      request.reqMethod)
    # No failure here - we just skip this message

  # Make sure the body is fully read
  if not request.reqBody.isNil and request.reqBody.kind != rbkCached:
    # Malformed body exceptions here are not handled - we can't respond after the
    # user-provided callback has started.

    # TODO: `readAll` keeps the whole thing in memory. Replace it.
    # `await` inside `try` is broken: https://github.com/nim-lang/Nim/issues/2528
    discard(await(request.reqBody.getStream.readAll))

  # Persistent connections
  # In HTTP 1.1 we assume that connection is persistent. Unless connection
  # header states otherwise.
  # In HTTP 1.0 we assume that the connection should not be persistent.
  # Unless the connection header states otherwise.
  let keepAlive =
    (request.protocol == HttpVer11 and
     request.headers.getOrDefault("connection").normalize != "close") or
    (request.protocol == HttpVer10 and
     request.headers.getOrDefault("connection").normalize == "keep-alive")

  return keepAlive

proc processClient(
  client: AsyncSocket, address: string,
  callback: proc (request: Request): Future[void] {.closure, gcsafe.}
) {.async.} =
  ## Implements full HTTP connection lifecycle and logging.
  while true:
    let keepAliveFut = processOneRequest(client, address, callback)
    yield keepAliveFut
    try:
      let keepAlive = keepAliveFut.read
      if not keepAlive: break
    except MalformedHttpException:
      # These are less likely to signal a serious error, so we log them as `debug`
      let e = getCurrentException()
      debug(
        "Failed to read request body: ",
        e.name, ": ", e.msg, "\L",
        e.getStackTrace
      )
      break
    except:
      let e = getCurrentException()
      warn(
        "Uncaught exception in HTTP handler for ", address, ": ",
        e.name, ": ", e.msg, "\L",
        e.getStackTrace
      )
      break

  client.close

proc serve*(server: AsyncHttpServer, port: Port,
            callback: proc (request: Request): Future[void] {.closure,gcsafe.},
            address = "") {.async.} =
  ## Starts the process of listening for incoming HTTP connections on the
  ## specified address and port.
  ##
  ## When a request is made by a client the specified callback will be called.
  server.socket = newAsyncSocket()
  if server.reuseAddr:
    server.socket.setSockOpt(OptReuseAddr, true)
  if server.reusePort:
    server.socket.setSockOpt(OptReusePort, true)
  server.socket.bindAddr(port, address)
  server.socket.listen()

  while true:
    # TODO: Causes compiler crash.
    #var (address, client) = await server.socket.acceptAddr()
    var fut = await server.socket.acceptAddr()
    asyncCheck processClient(fut.client, fut.address, callback)
    #echo(f.isNil)
    #echo(f.repr)

proc close*(server: AsyncHttpServer) =
  ## Terminates the async http server instance.
  server.socket.close()

when not defined(testing) and isMainModule:
  proc main =
    var server = newAsyncHttpServer()
    proc cb(req: Request) {.async.} =
      #echo(req.reqMethod, " ", req.url)
      #echo(req.headers)
      let headers = {"Date": "Tue, 29 Apr 2014 23:40:08 GMT",
          "Content-type": "text/plain; charset=utf-8"}
      await req.respond(Http200, "Hello World", headers.newHttpHeaders())

    asyncCheck server.serve(Port(5555), cb)
    runForever()
  main()

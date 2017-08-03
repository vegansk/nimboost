import boost.http.asynchttpserver
import unittest,
       asyncdispatch,
       threadpool,
       httpclient,
       net,
       os,
       strutils,
       boost.io.asyncstreams

const PORT = 9998.Port
const HOST = "localhost"

proc processBigData(req: Request) {.async.} =
  let s = req.reqBody.getStream
  var buff: array[4096, char]
  var length = 0
  while true:
    let readed = await s.readBuffer(addr buff, buff.len)
    if readed == 0:
      break
    length += readed
  await req.respond(Http200, $length)

proc serverThread =
  let finished = newFuture[void]("serverThread.completed")
  var server = newAsyncHttpServer()
  proc cb(req: Request) {.async.} =
    case req.reqMethod
    of "get":
      await req.respond(Http200, "Hello, world!")
    of "post":
      if req.url.path == "/count":
        await processBigData(req)
      elif req.url.path == "/discardbody":
        # Doesn't read the body!
        await req.respond(Http200, "discarded")
      elif req.url.path == "/quit":
        await req.respond(Http200, "")
        finished.complete
      else:
        let body = await req.body
        await req.respond(Http200, body)
    else:
      await req.respond(Http404, "Not found")

  asyncCheck server.serve(PORT, cb)
  waitFor(finished)

proc postRequest(path = "/", body = "*", count = 10_000_000): string =
  var s = newSocket()
  result = ""
  var left = body.len * count
  s.connect(HOST, PORT)
  s.send("POST " & path & " HTTP/1.0\c\L")
  s.send("Content-Type: application/octet-stream\c\L")
  s.send("Content-Length: " & $left & "\c\L\c\L")

  var buff = newSeq[char](if body.len == 1: 4096 else: body.len)
  if body.len == 1:
    for i in 0..<4096:
      buff[i] = body[0]
  else:
    for i in 0..<body.len:
      buff[i] = body[i]

  while left > 0:
    let cnt = if left < buff.len: left else: buff.len
    discard s.send(addr buff[0], cnt)
    left -= cnt

  var line = ""
  discard s.recv(line, 1024)
  result = line.splitLines[^1]

suite "asynchttpserver":

  let url = "http://" & HOST & ":" & $PORT.int

  spawn serverThread()
  defer: discard newHttpClient().postContent(url & "/quit", "")

  test "GET":
    check: newHttpClient().getContent(url) == "Hello, world!"

  test "POST":
    check: url.postRequest(body = "Hi!", count = 1) == "Hi!"

  test "POST (count)":
    check: (url & "/count").postRequest(count = 2_000_000) == $2_000_000

  test "Ignoring POST body shouldn't break connection":
    let client = newHttpClient()
    let body = "foo\c\L\c\Lbar\c\Lbaz"
    check: client.postContent(url & "/discardbody", body = body) == "discarded"
    check: client.getContent(url) == "Hello, world!"

  test "Should support requests with chunked encoding":
    # Client can't send chunked requests, so we drop down to sockets
    let reqLine = "POST " & url & "/ HTTP/1.1\c\L"
    let headers = "Transfer-Encoding: chunked\c\L"
    let body = "3\c\Lfoo\c\L3\c\Lbar\c\L0\c\L\c\L"
    let request = reqLine & headers & "\c\L" & body
    var s = newSocket()
    s.connect(HOST, PORT)
    s.send(request)
    # Skip the headers and get to the body
    while s.recvLine(100) != "\c\L":
      discard

    let respBody = s.recv(6)
    check: respBody == "foobar"

  test "Should fail for request with invalid transfer encoding":
    let reqLine = "POST " & url & "/ HTTP/1.1\c\L"
    let headers = "Transfer-Encoding: invalid\c\L"
    let body = "invalid"

    let request = reqLine & headers & "\c\L" & body
    var s = newSocket()
    s.connect(HOST, PORT)
    s.send(request)

    # Don't read more than we need to - we'll lock if we get past the message
    let resp = s.recv(12, 1000)
    check: resp == "HTTP/1.1 400"

  test "Should fail for request with invalid content length":
    let reqLine = "POST " & url & "/ HTTP/1.1\c\L"
    let headers = "Content-Length: invalid\c\L"
    let body = "invalid"

    let request = reqLine & headers & "\c\L" & body
    var s = newSocket()
    s.connect(HOST, PORT)
    s.send(request)

    # Don't read more than we need to - we'll lock if we get past the message
    let resp = s.recv(12, 1000)
    check: resp == "HTTP/1.1 400"

  test "Malformed chunked messages in discarded body should not crash the server":
    # Client can't send chunked requests, so we drop down to sockets
    let reqLine = "POST " & url & "/discardbody HTTP/1.1\c\L"
    let headers = "Transfer-Encoding: chunked\c\L"
    let body = "invalid\c\Lmessage"
    let request = reqLine & headers & "\c\L" & body
    var s = newSocket()
    s.connect(HOST, PORT)
    s.send(request)

    # Is there a better way?
    sleep(100)

    # Check that the server is working
    check: newHttpClient().getContent(url) == "Hello, world!"

  test "Malformed chunked messages in callback should not crash the server":
    # Client can't send chunked requests, so we drop down to sockets
    let reqLine = "POST " & url & "/ HTTP/1.1\c\L"
    let headers = "Transfer-Encoding: chunked\c\L"
    let body = "invalid\c\Lmessage"
    let request = reqLine & headers & "\c\L" & body
    var s = newSocket()
    s.connect(HOST, PORT)
    s.send(request)

    sleep(100)

    # Check that the server is working
    check: newHttpClient().getContent(url) == "Hello, world!"

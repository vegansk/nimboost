## The module implements asynchronous stream that handles multipart
## messages.

import ./httpcommon,
       asyncdispatch,
       boost.io.asyncstreams,
       strutils,
       boost.data.props

type
  MultiPartMessage* = ref object
    s: AsyncStream
    ct: ContentType
    finished: bool
    boundary: string
  MessagePart* = ref object
    msg: MultiPartMessage
    h: Props
    ct: ContentType
    cd: ContentDisposition

proc open*(t: typedesc[MultiPartMessage], s: AsyncStream, contentType: ContentType): MultiPartMessage =
  ## Opens multipart message with ``contentType`` for reading from stream ``s``.
  if not contentType.mimeType.startsWith("multipart"):
    raise newException(ValueError, "MultiPartMessage can't handle this mime-type: " & contentType.mimeType)
  if contentType.boundary.len == 0:
    raise newException(ValueError, "ContentType boundary is absent")
  MultiPartMessage(s: s, ct: contentType, boundary: "--" & contentType.boundary)

proc atEnd*(m: MultiPartMessage): bool =
  m.finished

proc readNextPart*(m: MultiPartMessage): Future[MessagePart] {.async.} =
  ## Returns the next part of the message ``m`` or nil if it's ended
  if m.atEnd:
    return
  let s = m.s
  var line = await s.readLine
  if line.len == 0:
    m.finished = true
    return
  if not line.startsWith(m.boundary):
    m.finished = true
    return
  if line.endsWith("--"):
    m.finished = true
    return
  let headers = await s.readHeaders
  result = MessagePart(msg: m, h: headers)
  for k, v in headers:
    if k.cmpIgnoreCase("Content-Type") == 0:
      result.ct = v.parseContentType
    elif k.cmpIgnoreCase("Content-Disposition") == 0:
      result.cd = v.parseContentDisposition

proc readPartData*(p: MessagePart): AsyncStream =
  discard

proc headers*(p: MessagePart): Props =
  ## Returns http headers of the multipart message part ``p``
  p.h

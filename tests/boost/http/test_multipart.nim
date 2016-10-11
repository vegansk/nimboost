import boost.http.multipart,
       boost.http.httpcommon,
       asyncdispatch,
       boost.io.asyncstreams,
       boost.data.props,
       unittest,
       strutils

const MP = """-----------------------------9051914041544843365972754266
Content-Disposition: form-data;
  name="text"
Content-Transfer-Encoding: 8bit

text default
-----------------------------9051914041544843365972754266
Content-Disposition: form-data; name="file1"; filename="a.txt"
Content-Type: text/plain

Content of a.txt.
-----------------------------9051914041544843365972754266
Content-Disposition: form-data; name="file2"; filename="a.html"
Content-Type: text/html

<!DOCTYPE html><title>Content of a.html.</title>
-----------------------------9051914041544843365972754266--

""".replace("\n", "\c\L")

const MPWithPreamble = """This is the preamble.
It should be ignored
--12boundary34
Content-Disposition: form-data; name="foo"
Content-Type: text/plain

First part.
--12boundary34--""".replace("\n", "\c\L")

# trigger partial detection branch for buffer size 10
const TrickyMP = """--12345
Content-Disposition: form-data; name="text"
Convent-Transfer-Encoding: 8bit

abc
--1234(not a boundary yet)--12
--12345--
""".replace("\n", "\c\L")

suite "Multipart":
  test "read multipart message":
    let ct = "multipart/form-data; boundary=---------------------------9051914041544843365972754266".parseContentType
    let s = newAsyncStringStream(MP)

    let mp = MultiPartMessage.open(s, ct)
    check: not mp.atEnd

    var part = waitFor mp.readNextPart
    require: not part.isNil
    check: not mp.atEnd
    check: part.headers.toSeq == @{
      "Content-Disposition": "form-data;name=\"text\"",
      "Content-Transfer-Encoding": "8bit"
    }
    check: part.encoding == "8bit"
    var ps = part.getPartDataStream()
    var data = waitFor ps.readAll
    check: data == "text default"

    part = waitFor mp.readNextPart
    require: not part.isNil
    check: not mp.atEnd
    check: part.headers.toSeq == @{
      "Content-Disposition": "form-data; name=\"file1\"; filename=\"a.txt\"",
      "Content-Type": "text/plain"
    }
    ps = part.getPartDataStream()
    data = waitFor ps.readAll
    check: data == "Content of a.txt."

    part = waitFor mp.readNextPart
    require: not part.isNil
    check: not mp.atEnd
    check: part.headers.toSeq == @{
      "Content-Disposition": "form-data; name=\"file2\"; filename=\"a.html\"",
      "Content-Type": "text/html"
    }
    ps = part.getPartDataStream()
    data = waitFor ps.readAll
    check: data == "<!DOCTYPE html><title>Content of a.html.</title>"

    part = waitFor mp.readNextPart
    check: mp.atEnd
    check: part.isNil

  test "should skip preamble":
    let ct = "multipart/form-data; boundary=12boundary34".parseContentType
    let s = newAsyncStringStream(MPWithPreamble)

    let mp = MultipartMessage.open(s, ct)
    check: not mp.atEnd

    var part = waitFor mp.readNextPart
    require: not part.isNil
    check: not mp.atEnd
    check: part.headers.toSeq == @{
      "Content-Disposition": "form-data; name=\"foo\"",
      "Content-Type": "text/plain"
    }

    var ps = part.getPartDataStream()
    var data = waitFor ps.readAll
    check: data == "First part."

    part = waitFor mp.readNextPart
    check: mp.atEnd
    check: part.isNil

  test "should properly handle part of boundary in content":

    # Small enough to trigger partial boundary detection, but large
    # enough to store the boundary
    const BufSize = 10

    let ct = "multipart/form-data; boundary=12345".parseContentType
    let s = newAsyncStringStream(TrickyMP)
    let mp = MultipartMessage.open(s, ct)
    check: not mp.atEnd

    var part = waitFor mp.readNextPart
    require: not part.isNil
    check: not mp.atEnd

    let ps = part.getPartDataStream()

    # Read the part by small chunks
    var acc = ""
    while not ps.atEnd:
      let data = waitFor ps.readData(BufSize)
      check: data.len <= BufSize
      acc.add(data)

    check: acc == "abc\c\L--1234(not a boundary yet)--12"

  test "should work even when the buffer doesn't fit the boundary":

    # shorter than the boundary
    const BufSize = 4

    let ct = "multipart/form-data; boundary=12345".parseContentType
    let s = newAsyncStringStream(TrickyMP)
    let mp = MultipartMessage.open(s, ct)
    check: not mp.atEnd

    var part = waitFor mp.readNextPart
    require: not part.isNil
    check: not mp.atEnd

    let ps = part.getPartDataStream()

    # Read the part by small chunks
    var acc = ""
    while not ps.atEnd:
      let data = waitFor ps.readData(BufSize)
      check: data.len <= BufSize
      acc.add(data)

    check: acc == "abc\c\L--1234(not a boundary yet)--12"

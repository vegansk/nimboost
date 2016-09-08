import boost.http.multipart,
       boost.http.httpcommon,
       asyncdispatch,
       boost.io.asyncstreams,
       boost.data.props,
       unittest,
       strutils

const MP = """-----------------------------9051914041544843365972754266
Content-Disposition: form-data; name="text"

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

"""
suite "Multipart":
  test "read multipart message":
    let ct = "multipart/form-data; boundary=---------------------------9051914041544843365972754266".parseContentType
    let s = newAsyncStringStream(MP)

    let mp = MultiPartMessage.open(s, ct)
    check: not mp.atEnd

    var part = waitFor mp.readNextPart
    check: not part.isNil
    check: not mp.atEnd
    check: part.headers.toSeq == @{ "Content-Disposition": "form-data; name=\"text\"" }

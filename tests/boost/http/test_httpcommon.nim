import boost/http/httpcommon,
       boost/data/props,
       unittest,
       strtabs,
       sequtils,
       asyncdispatch,
       boost/io/asyncstreams

suite "HTTP utils":
  test "URL encode/decode":
    check: "Hello, world!".urlEncode == "Hello%2C+world%21"
    check: "Hello%2C+world%21".urlDecode == "Hello, world!"
    check: "Привет, мир!".urlEncode == "%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82%2C+%D0%BC%D0%B8%D1%80%21"
    check: "%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82%2C+%D0%BC%D0%B8%D1%80%21".urlDecode == "Привет, мир!"
    check: "!@#$%^&*()_+".urlEncode == "%21%40%23%24%25%5E%26%2A%28%29_%2B"
    check: "%21%40%23%24%25%5E%26%2A%28%29_%2B".urlDecode == "!@#$%^&*()_+"

  test "x-www-form-urlencoded encode/decode":
    var f = newProps({"Name": "Jonathan Doe", "Age": "23", "Formula": "a + b == 13 %!"})
    let s = "Name=Jonathan+Doe&Age=23&Formula=a+%2B+b+%3D%3D+13+%25%21"
    check: f.formEncode == s
    f = s.formDecode
    check: f["Name"] == "Jonathan Doe"
    check: f["Age"] == "23"
    check: f["Formula"] == "a + b == 13 %!"

  test "Content-Type":
    var ct = " application/octetstream".parseContentType
    check: ct.mimeType == "application/octetstream"
    check: $ct == "application/octetstream"

    ct = "text/html; charset=utf-8".parseContentType
    check: ct.mimeType == "text/html"
    check: ct.charset == "utf-8"
    check: $ct == "text/html; charset=utf-8"

    ct = "multipart/form-data;boundary=something".parseContentType
    check: ct.mimeType == "multipart/form-data"
    check: ct.boundary == "something"
    check: $ct == "multipart/form-data; boundary=something"

  test "Content-Disposition":
    var cd = "attachment;filename=\"genome.jpeg\";modification-date=\"Wed, 12 Feb 1997 16:29:51 -0500\";".parseContentDisposition
    check: cd.disposition == "attachment"
    check: cd.filename == "genome.jpeg"

  test "Headers":
    check: "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".parseHeader == (
      "Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    )
    # Also check multiline headers
    const HEADERS = """Content-Disposition: file;
  filename="file2.gif"
Content-Type: image/gif
Content-Transfer-Encoding: binary

"""
    let s = newAsyncStringStream(HEADERS)
    let h = waitFor s.readHeaders
    check: h.toSeq == @[
      ("Content-Disposition", "file;filename=\"file2.gif\""),
      ("Content-Type", "image/gif"),
      ("Content-Transfer-Encoding", "binary")
    ]
    # And now check that the stream is not corrupted
    check: not s.atEnd
    check: (waitFor s.readLine).len == 0
    check: s.atEnd

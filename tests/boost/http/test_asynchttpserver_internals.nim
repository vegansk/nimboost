## This is in a separate file since we need access to private functions, so
## we have to include rather than import.

include boost/http/asynchttpserver

import unittest,
       asyncdispatch,
       strutils,
       boost/io/asyncstreams

suite "RequestBodyStream":
  test "should fulfill its contracts":
    # This is a catch-all test that checks a few invariants with the same setup.
    # Splitting it would lead to too much duplication/complexity.

    # We have no internal buffering, and we don't look at the data, so this
    # should be enough.
    let bodyStr = "0123456789abcdef"
    let followingData = "#####"
    # We check the case when we ask for more bytes than the body contains, too.
    for i in 0..bodyStr.len.succ:
      for j in max(0, bodyStr.len - i)..bodyStr.len.succ:
        # TODO: This produces a lot of output on failure
        # https://github.com/nim-lang/Nim/issues/6376
        checkpoint("i = $#, j = $#" % [$i, $j])
        let underlying = newAsyncStringStream(bodyStr & followingData)
        let body = newRequestBodyStream(underlying, bodyStr.len)
        let s1 = waitFor(body.readData(i))

        let expectedAtEnd = (i >= bodyStr.len)
        check: body.atEnd == expectedAtEnd

        let s2 = waitFor(body.readData(j))
        let s3 = waitFor(body.readAll)

        let expectedS1 = bodyStr[0..<min(bodyStr.len, i)]
        check: s1 == expectedS1
        check: (s1 & s2) == bodyStr
        check: s3.len == 0
        check: underlying.getPosition == bodyStr.len

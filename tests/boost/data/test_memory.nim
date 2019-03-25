import boost/data/memory,
       unittest

suite "Memory":
  test "findInMem":
    var buf = "0123456789"
    var s1 = "123"
    var s2 = "8910"
    var s3 = "111"

    check: findInMem(addr buf[0], buf.len, addr s1[0], s1.len) == (1, 3)
    check: findInMem(addr buf[0], buf.len, addr s2[0], s2.len) == (8, 2)
    check: findInMem(addr buf[0], buf.len, addr s3[0], s3.len) == (-1, 0)

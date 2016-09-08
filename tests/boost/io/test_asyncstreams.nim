import boost.io.asyncstreams
import unittest, asyncdispatch, asyncnet, threadpool, os, strutils

const PORT = Port(9999)

suite "asyncstreams":

  when not defined(noNet):
    test "AsyncSocketStream":
      proc runSocketServer =
        proc serve {.async.} =
          var s = newAsyncSocket()
          s.bindAddr(PORT)
          s.listen
          let c = newAsyncSocketStream(await s.accept)
          let ch = await c.readChar
          await c.writeChar(ch)
          let line = await c.readLine
          await c.writeLine("Hello, " & line)
          c.close
          s.close

        proc run {.gcsafe.} =
          waitFor serve()

        spawn run()

      runSocketServer()

      proc doTest {.async.} =
        let s = newAsyncSocket()
        await s.connect("localhost", PORT)
        let c = newAsyncSocketStream(s)

        await c.writeChar('A')
        let ch = await c.readChar
        check: ch == 'A'

        await c.writeLine("World!")
        let line = await c.readLine
        check: line == "Hello, World!"
      waitFor doTest()

  test "AsyncFileStream":
    proc doTest {.async.} =
      let fname = getTempDir() / "asyncstreamstest.nim"
      var s = newAsyncFileStream(fname, fmReadWrite)
      await s.writeLine("Hello, world!")
      s.setPosition(0)
      let line = await s.readLine
      check: line == "Hello, world!"
      check: not s.atEnd
      discard await s.readLine
      check: s.atEnd

      # File doesn't implement neither peekBuffer nor peekLine operations.
      # But it allows get/set position operation. So this must work
      s.setPosition(0)
      let l1 = await s.peekLine
      let l2 = await s.readLine
      check: l1 == l2

      fname.removeFile
    waitFor doTest()

  test "AsyncStringStream":
    proc doTest {.async.} =
      let s = newAsyncStringStream()
      await s.writeLine("Hello, world!")
      s.setPosition(0)
      let line = await s.readLine
      check: line == "Hello, world!"
      check: not s.atEnd
      discard await s.readLine
      check: s.atEnd
    waitFor doTest()

  test "Operations":
    proc doTest {.async.} =
      let s = newAsyncStringStream()

      await s.writeChar('H')
      s.setPosition(0)
      let ch = await s.readChar
      check: ch == 'H'

      s.setPosition(0)
      await s.writeLine("Hello, world!")
      s.setPosition(0)
      let line = await s.readLine
      check: line == "Hello, world!"

      # String doesn't implement neither peekBuffer nor peekLine operations.
      # But it allows get/set position operation. So this must work
      s.setPosition(0)
      let l1 = await s.peekLine
      let l2 = await s.readLine
      check: l1 == l2

      s.setPosition(0)
      let all = await s.readAll
      check: all == "Hello, world!\n"

      s.setPosition(0)
      await s.writeByte(42)
      s.setPosition(0)
      let b = await s.readByte
      check: b == 42

      s.setPosition(0)
      await s.writeFloat(1.0)
      s.setPosition(0)
      let f = await s.readFloat
      check: f == 1.0

      s.setPosition(0)
      await s.writeBool(true)
      s.setPosition(0)
      let bo = await s.readBool
      check: bo

      s.setPosition(1000)
      try:
        discard await s.readBool
      except IOError:
        return
      check: false
    waitFor doTest()

  test "Example for the documentation":
    proc main {.async.} =
      var s = newAsyncStringStream("""Hello
world!""")
      var res = newSeq[string]()
      while true:
        let l = await s.readLine()
        if l == "":
          break
        res.add(l)
      doAssert(res.join(", ") == "Hello, world!")
    waitFor main()

  test "Buffered stream":
    proc doTest {.async.} =
      # 100 bytes of data
      const data = "01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
      let ss = newAsyncStringStream(data)
      # Read 10 bytes chunks
      let bs = newAsyncBufferedStream(ss, 10)

      var pd = await bs.peekData(5)
      var rd = await bs.readData(5)
      check: rd == pd
      check: rd == "01234"

      pd = await bs.peekData(5)
      rd = await bs.readData(5)
      check: rd == pd
      check: rd == "56789"

      pd = await bs.peekData(10)
      rd = await bs.readData(10)
      check: rd == pd
      check: rd == "0123456789"

      pd = await bs.peekData(100)
      rd = await bs.readData(100)
      check: rd == pd
      check: rd == "0123456789"

      # If we read the data, we get just buffered bytes
      discard await bs.readData(7)
      rd = await bs.readData(4)
      check: rd == "789"

      # But if we peek the data, we can get more
      discard await bs.readData(7)
      pd = await bs.peekData(4)
      rd = await bs.readData(4)
      check: rd == pd
      check: rd == "7890"

      bs.setPosition(0)
      pd = await bs.peekLine
      check: pd == data

    waitFor doTest()

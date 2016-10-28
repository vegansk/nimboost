from boost.http.asynchttpserver import RequestBody, getStream
from boost.io.asyncstreams import readAll
import boost.http.multipart

proc runSocketServer =
  proc run {.gcsafe.} =
    settings:
      port = PORT
      appName = "/foo"
      bindAddr = HOST

    routes:
      get "/":
        resp "Hello World"

      get "/resp":
        if true:
          resp "This should be the response"
        resp "This should NOT be the response"

      get "/halt":
        halt Http502, "I'm sorry, this page has been halted."
        resp "test"

      get "/halt":
        resp "<h1>Not halted!</h1>"

      get "/guess/@who":
        if @"who" != "Frank": pass()
        resp "You've found me!"

      get "/guess/@_":
        resp "Haha. You will never find me!"

      get "/redirect/@url/?":
        redirect(uri(@"url"))

      get "/win":
        cond random(5) < 3
        resp "<b>You won!</b>"

      get "/win":
        resp "<b>Try your luck again, loser.</b>"

      get "/profile/@id/@value?/?":
        var html = ""
        html.add "<b>Msg: </b>" & @"id" &
                "<br/><b>Name: </b>" & @"value"
        html.add "<br/>"
        html.add "<b>Params: </b>" & $request.params

        resp html

      get "/attachment":
        attachment "public/root/index.html"
        resp "blah"

      get "/error":
        proc blah = raise newException(Exception, "BLAH BLAH BLAH")
        blah()

      get "/live":
        await response.sendHeaders()
        for i in 0 .. 10:
          await response.send("The number is: " & $i & "</br>")
          await sleepAsync(1000)
        response.client.close()

      # curl -v -F file='blah' http://dom96.co.cc:5000
      # curl -X POST -d 'test=56' localhost:5000/post

      post "/post":
        body.add "Received: <br/>"
        let fd = await request.formData.toMultiData
        body.add($fd)
        body.add "<br/>\n"
        body.add($request.params)

        status = Http200

      get "/post":
        resp """
      <form name="input" action="$1" method="post">
      First name: <input type="text" name="FirstName" value="Mickey" /><br />
      Last name: <input type="text" name="LastName" value="Mouse" /><br />
      <input type="submit" value="Submit" />
      </form>""" % [uri("/post", absolute = false)]

      get "/file":
        resp """
      <form action="/post" method="post"
      enctype="multipart/form-data">
      <label for="file">Filename:</label>
      <input type="file" name="file" id="file" />
      <br />
      <input type="submit" name="submit" value="Submit" />
      </form>"""

      get re"^\/([0-9]{2})\.html$":
        resp request.matches[0]

      patch "/patch":
        body.add "Received: "
        let b: string = await request.body.getStream.readAll
        body.add($b)
        status = Http200

      post "/multipart":
        let mp = request.formData
        var acc = newSeq[string]()
        while not mp.atEnd:
          let part = await mp.readNextPart()
          if part == nil: break

          acc.add(part.contentDisposition.name)

          let stream = part.getPartDataStream()
          if stream == nil: break

          let contentFut = readAll(stream)
          let content = await contentFut
          acc.add(content)

        resp(acc.join(","))

    runForever()

  spawn run()

runSocketServer()
#TODO: Wait for server to start
sleep(1000)

proc url(path: string): auto = "http://" & HOST & ":" & $(PORT.int) & "/foo" & path

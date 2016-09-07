# Copyright (C) 2015 Dominik Picheta
# MIT License - Look at license.txt for details.
import boost.http.jester, asyncdispatch, strutils, random, os, asyncnet, re, threadpool, httpclient, unittest

const PORT = 9997.Port
const HOST = "localhost"

include run_test_server

suite "Jester":
  let client = newAsyncHttpClient()

  test "can access root":
    # If this fails then alltest is likely not running.
    let resp = waitFor client.get(url"/")
    check resp.status.startsWith("200")
    check resp.body == "Hello World"

  test "/halt":
    let resp = waitFor client.get(url"/halt")
    check resp.status.startsWith("502")
    check resp.body == "I'm sorry, this page has been halted."

  test "/guess":
    let resp = waitFor client.get(url"/guess/foo")
    check resp.body == "Haha. You will never find me!"
    let resp2 = waitFor client.get(url"/guess/Frank")
    check resp2.body == "You've found me!"

  test "/redirect":
    let resp = waitFor client.request(url"/redirect/halt", httpGet)
    check resp.headers["location"] == url"/halt"

  test "regex":
    let resp = waitFor client.get(url"/02.html")
    check resp.body == "02"

  test "resp":
    let resp = waitFor client.get(url"/resp")
    check resp.body == "This should be the response"

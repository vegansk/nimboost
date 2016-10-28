# Copyright (C) 2015 Dominik Picheta
# MIT License - Look at license.txt for details.
import boost.http.jester, asyncdispatch, strutils, random, os, asyncnet, re, threadpool, httpclient, unittest

const PORT = 9997.Port
const HOST = "localhost"

include impl.run_test_server

suite "Jester":

  setup:
    let client = newAsyncHttpClient()

  teardown:
    client.close

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

  test "multipart":
    var md = newMultipartData()
    md.add("foo", "bar")
    md.add("baz", "qux")
    let resp = waitFor client.post(url"/multipart", multipart = md)
    check resp.body == "foo,bar,baz,qux"

  test "multipart + keepAlive":
    var md = newMultipartData()
    md.add("foo", "bar")
    let resp = waitFor client.post(url"/multipart", multipart = md)
    check resp.body == "foo,bar"

    let resp2 = waitFor client.get(url"/resp")
    let body2 = resp2.body
    check body2 == "This should be the response"
